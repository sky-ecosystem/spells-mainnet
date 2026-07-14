#!/usr/bin/env bash
# Install an age-eligible stable Foundry release from GitHub.com.
# GitHub.com and Foundry's official release workflow are the pinned trust roots:
# verify the archive before extraction and each installed binary before execution.
# If a later step fails after destination mutation begins, restore the prior binaries.
# The script's explicit exit 2 means installation succeeded but PATH setup is incomplete.

set -euo pipefail

GITHUB_HOST=github.com
REPOSITORY=foundry-rs/foundry
QUALIFIED_REPOSITORY=$GITHUB_HOST/$REPOSITORY
SIGNER_WORKFLOW=foundry-rs/foundry/.github/workflows/release.yml
MINIMUM_RELEASE_AGE_SECONDS=604800
BINARIES=(forge cast anvil chisel)

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

# Validate local prerequisites, authentication, and the supported target before download.
for command in gh git bash tar install uname mktemp mkdir rm rmdir cp sort sed dirname; do
    command -v "$command" >/dev/null 2>&1 || die "required command not found: $command"
done

if command -v sha256sum >/dev/null 2>&1; then
    sha256() {
        sha256sum "$1" | sed 's/[[:space:]].*$//'
    }
elif command -v shasum >/dev/null 2>&1; then
    sha256() {
        shasum -a 256 "$1" | sed 's/[[:space:]].*$//'
    }
else
    die 'required command not found: sha256sum or shasum'
fi

case "$(uname -s)" in
    Linux) PLATFORM=linux ;;
    Darwin) PLATFORM=darwin ;;
    *) die "unsupported operating system: $(uname -s)" ;;
esac

case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    arm64 | aarch64) ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
esac

gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1 || die "GitHub CLI is not authenticated for $GITHUB_HOST"

SCRIPT_PATH=${BASH_SOURCE[0]}
SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null) || die 'installer is not in a Git checkout'
SOURCE_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
INSTALLER_SHA256=$(sha256 "$SCRIPT_PATH")

# Use the latest stable release only after it is seven days old; otherwise use its predecessor.
LATEST_RECORD=$(gh api "repos/$REPOSITORY/releases/latest" --hostname "$GITHUB_HOST" \
    --jq "[.tag_name, .published_at, .html_url, (if (now - (.published_at | fromdateiso8601)) < $MINIMUM_RELEASE_AGE_SECONDS then \"previous\" else \"latest\" end)] | @tsv")
IFS=$'\t' read -r VERSION PUBLISHED_AT RELEASE_URL SELECTION <<< "$LATEST_RECORD"

if [ "$SELECTION" = previous ]; then
    SELECTED_RECORD=$(gh api --paginate "repos/$REPOSITORY/releases?per_page=100" --hostname "$GITHUB_HOST" \
        --jq '.[] | select(.draft == false and .prerelease == false) | [.tag_name, .published_at, .html_url] | @tsv' \
        | sort -k2,2r \
        | sed -n '2p')
    [ -n "$SELECTED_RECORD" ] || die 'latest stable release is less than seven days old and no previous stable release was found'
    IFS=$'\t' read -r VERSION PUBLISHED_AT RELEASE_URL <<< "$SELECTED_RECORD"
    SELECTION_REASON='fallback to previous stable because latest is less than seven days old'
elif [ "$SELECTION" = latest ]; then
    SELECTION_REASON='latest eligible stable (published at least seven days ago)'
else
    die 'unexpected release-selection response from GitHub'
fi

ARCHIVE="foundry_${VERSION}_${PLATFORM}_${ARCH}.tar.gz"
DESTINATION="$HOME/.foundry/bin"
# Preserve the previous installation in temporary state so destination changes can be rolled back.
TEMP_DIR=$(mktemp -d)
BACKUP_DIR="$TEMP_DIR/previous-installation"
ROLLBACK_REQUIRED=0
DESTINATION_CREATED=0

cleanup() {
    exit_status=$?
    trap - EXIT INT TERM
    set +e

    rollback_failed=0
    if [ "$ROLLBACK_REQUIRED" -eq 1 ]; then
        printf '\nInstallation did not complete; restoring the previous Foundry binaries.\n' >&2
        for binary in "${BINARIES[@]}"; do
            if ! rm -f "$DESTINATION/$binary"; then
                printf 'Rollback error: could not remove %s\n' "$DESTINATION/$binary" >&2
                rollback_failed=1
                continue
            fi
            if [ -e "$BACKUP_DIR/$binary" ] || [ -L "$BACKUP_DIR/$binary" ]; then
                if ! cp -pP "$BACKUP_DIR/$binary" "$DESTINATION/$binary"; then
                    printf 'Rollback error: could not restore %s\n' "$DESTINATION/$binary" >&2
                    rollback_failed=1
                fi
            fi
        done
        if [ "$DESTINATION_CREATED" -eq 1 ] && { [ -e "$DESTINATION" ] || [ -L "$DESTINATION" ]; }; then
            if ! rmdir "$DESTINATION"; then
                printf 'Rollback error: could not remove newly created directory %s\n' "$DESTINATION" >&2
                rollback_failed=1
            fi
        fi
        if [ "$rollback_failed" -eq 0 ]; then
            printf 'Previous Foundry installation restored.\n' >&2
        else
            printf 'Error: Foundry rollback was incomplete; inspect %s before continuing.\n' "$DESTINATION" >&2
        fi
    fi

    if ! rm -rf "$TEMP_DIR"; then
        printf 'Cleanup error: could not remove temporary directory %s\n' "$TEMP_DIR" >&2
    fi
    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Record provenance before downloading, verify before extraction, and verify again before execution.
printf 'Foundry release: %s\n' "$VERSION"
printf 'Published at: %s\n' "$PUBLISHED_AT"
printf 'Release URL: %s\n' "$RELEASE_URL"
printf 'Selection policy: %s\n' "$SELECTION_REASON"
printf 'spells-mainnet commit: %s\n' "$SOURCE_COMMIT"
printf 'Installer SHA-256: %s\n' "$INSTALLER_SHA256"

gh release download "$VERSION" --repo "$QUALIFIED_REPOSITORY" --pattern "$ARCHIVE" --dir "$TEMP_DIR"

verify_attestation() {
    gh attestation verify "$1" \
        --repo "$REPOSITORY" \
        --hostname "$GITHUB_HOST" \
        --signer-workflow "$SIGNER_WORKFLOW" \
        --format json \
        --jq '.[] | {subjects: [.verificationResult.statement.subject[].name], signer: .verificationResult.signature.certificate.buildSignerURI, source: .verificationResult.signature.certificate.sourceRepositoryURI}'
}

printf '\nArchive attestation:\n'
verify_attestation "$TEMP_DIR/$ARCHIVE"

EXTRACTED_DIR="$TEMP_DIR/extracted"
mkdir "$EXTRACTED_DIR"
tar -xzf "$TEMP_DIR/$ARCHIVE" -C "$EXTRACTED_DIR" "${BINARIES[@]}"

if [ -e "$DESTINATION" ] || [ -L "$DESTINATION" ]; then
    [ -d "$DESTINATION" ] || die "installation destination is not a directory: $DESTINATION"
else
    DESTINATION_CREATED=1
fi

mkdir -m 0700 "$BACKUP_DIR"
for binary in "${BINARIES[@]}"; do
    if [ -e "$DESTINATION/$binary" ] || [ -L "$DESTINATION/$binary" ]; then
        if [ ! -f "$DESTINATION/$binary" ] && [ ! -L "$DESTINATION/$binary" ]; then
            die "existing Foundry path is not a file or symbolic link: $DESTINATION/$binary"
        fi
        cp -pP "$DESTINATION/$binary" "$BACKUP_DIR/$binary"
    fi
done

ROLLBACK_REQUIRED=1
if [ "$DESTINATION_CREATED" -eq 1 ]; then
    install -d -m 0755 "$DESTINATION"
fi
for binary in "${BINARIES[@]}"; do
    install -m 0755 "$EXTRACTED_DIR/$binary" "$DESTINATION/$binary"
done

VERSION_OUTPUTS=()
printf '\nInstalled binary attestations and versions:\n'
for binary in "${BINARIES[@]}"; do
    printf '%s attestation:\n' "$binary"
    verify_attestation "$DESTINATION/$binary"
    VERSION_OUTPUT=$("$DESTINATION/$binary" --version)
    VERSION_OUTPUTS+=("$VERSION_OUTPUT")
    printf '%s\n' "$VERSION_OUTPUT"
done
ROLLBACK_REQUIRED=0

# Summarize the verified result; only incomplete PATH setup produces the script's explicit exit 2.
printf '\nEvidence summary:\n'
printf '  Source: spells-mainnet %s; installer SHA-256 %s\n' "$SOURCE_COMMIT" "$INSTALLER_SHA256"
printf '  Release: %s; %s; %s\n' "$VERSION" "$PUBLISHED_AT" "$RELEASE_URL"
printf '  Policy decision: %s\n' "$SELECTION_REASON"
printf '  Archive attestation: verified against %s\n' "$SIGNER_WORKFLOW"
printf '  Binary attestations: forge, cast, anvil, and chisel verified against %s\n' "$SIGNER_WORKFLOW"
printf '  Installed versions:\n'
for version_output in "${VERSION_OUTPUTS[@]}"; do
    printf '    %s\n' "$version_output"
done

case ":$PATH:" in
    *":$DESTINATION:"*) ;;
    *)
        printf '\nFoundry was installed and verified, but %s is not in PATH.\n' "$DESTINATION" >&2
        printf '%s\n' 'Run: export PATH="$HOME/.foundry/bin:$PATH"' >&2
        printf '%s\n' 'Add the same export to your shell profile, then start a new shell before continuing.' >&2
        exit 2
        ;;
esac

printf '\nFoundry installation and verification completed successfully.\n'
