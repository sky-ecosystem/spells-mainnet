#!/usr/bin/env bash
# Verify or install an age-eligible stable Foundry release from GitHub.com.
# GitHub.com and Foundry's official release workflow are the pinned trust roots.
# Binaries are verified before execution; installation failures restore prior binaries.

set -euo pipefail

GITHUB_HOST="github.com"
REPOSITORY="foundry-rs/foundry"
QUALIFIED_REPOSITORY="${GITHUB_HOST}/${REPOSITORY}"
SIGNER_WORKFLOW="${REPOSITORY}/.github/workflows/release.yml"
SIGNER_PREFIX="https://${GITHUB_HOST}/${SIGNER_WORKFLOW}@refs/tags/"
SOURCE_REPOSITORY="https://${GITHUB_HOST}/${REPOSITORY}"
MINIMUM_RELEASE_AGE_SECONDS="1209600"
BINARIES=("forge" "cast" "anvil" "chisel")
INSTALL_REMEDIATION=0
REQUESTED_RELEASE=
FORCE_RELEASE=0

die() {
    printf 'Error: %s' "$*" >&2
    if [ "$INSTALL_REMEDIATION" -eq 1 ] && [ -n "${VERSION:-}" ]; then
        printf '; run make install-foundry release=%s' "$VERSION" >&2
        if [ "$FORCE_RELEASE" -eq 1 ]; then
            printf ' force=1' >&2
        fi
    fi
    printf '\n' >&2
    exit 1
}

usage() {
    printf 'Usage: %s verify | %s verify -r vMAJOR.MINOR.PATCH -f | %s install -r vMAJOR.MINOR.PATCH [-f]\n' "${0##*/}" "${0##*/}" "${0##*/}" >&2
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | sed 's/[[:space:]].*$//'
    else
        shasum -a 256 "$1" | sed 's/[[:space:]].*$//'
    fi
}

validate_environment() {
    local command

    for command in gh git; do
        command -v "$command" >/dev/null 2>&1 || die "required command not found: $command"
    done
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        die 'required command not found: sha256sum or shasum'
    fi
    gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1 || die "GitHub CLI is not authenticated for $GITHUB_HOST"
}

is_rosetta() {
    if [ "$(uname -s)" = Darwin ] && command -v sysctl >/dev/null 2>&1; then
        [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = 1 ]
        return $?
    fi
    return 1
}

validate_install_platform() {
    case "$(uname -s)" in
        Linux) PLATFORM=linux ;;
        Darwin) PLATFORM=darwin ;;
        *) die "unsupported operating system: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64 | amd64)
            if is_rosetta; then ARCH=arm64; else ARCH=amd64; fi
            ;;
        arm64 | aarch64) ARCH=arm64 ;;
        *) die "unsupported architecture: $(uname -m)" ;;
    esac
}

collect_source_metadata() {
    local script_path script_dir repo_root

    script_path=${BASH_SOURCE[0]}
    script_dir=$(cd "$(dirname "$script_path")" && pwd)
    repo_root=$(git -C "${script_dir}/../.." rev-parse --show-toplevel 2>/dev/null) || die 'setup CLI is not in a Git checkout'
    SOURCE_COMMIT=$(git -C "$repo_root" rev-parse HEAD)
    CLI_SHA256=$(sha256 "$script_path")
}

select_release() {
    local selected_record

    selected_record=$(gh api --paginate "repos/${REPOSITORY}/releases?per_page=100" --hostname "$GITHUB_HOST" \
        --jq ".[] | select(.draft == false and .prerelease == false and .immutable == true and (.tag_name | test(\"^v[0-9]+\\\\.[0-9]+\\\\.[0-9]+$\")) and (now - (.published_at | fromdateiso8601)) >= ${MINIMUM_RELEASE_AGE_SECONDS}) | [.tag_name, .published_at, .html_url] | @tsv" \
        | sort -k2,2r \
        | sed -n '1p')
    [ -n "$selected_record" ] || die 'no immutable stable Foundry release published at least 14 days ago was found'
    IFS=$'\t' read -r VERSION PUBLISHED_AT RELEASE_URL <<< "$selected_record"
    SELECTION_REASON='newest immutable stable release published at least 14 days ago'
}

load_requested_release() {
    local record requested_draft requested_prerelease requested_immutable release_age_seconds

    [[ "$REQUESTED_RELEASE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "requested Foundry release does not use a stable version tag: $REQUESTED_RELEASE"
    record=$(gh api "repos/${REPOSITORY}/releases/tags/${REQUESTED_RELEASE}" --hostname "$GITHUB_HOST" \
        --jq '[.tag_name, .published_at, .html_url, .draft, .prerelease, .immutable, ((now - (.published_at | fromdateiso8601)) | floor)] | @tsv') \
        || die "could not find requested Foundry release metadata for $REQUESTED_RELEASE"
    IFS=$'\t' read -r VERSION PUBLISHED_AT RELEASE_URL requested_draft requested_prerelease requested_immutable release_age_seconds <<< "$record"
    [ "$VERSION" = "$REQUESTED_RELEASE" ] || die "requested Foundry release metadata does not match $REQUESTED_RELEASE"
    [ "$requested_draft" = false ] && [ "$requested_prerelease" = false ] \
        || die "requested Foundry release is not stable: $REQUESTED_RELEASE"
    [ "$requested_immutable" = true ] || die "requested Foundry release is not immutable: $REQUESTED_RELEASE"
    [ "$release_age_seconds" -ge 0 ] || die "requested Foundry release has a future publication date: $REQUESTED_RELEASE"
    if [ "$FORCE_RELEASE" -eq 1 ]; then
        [ "$release_age_seconds" -lt "$MINIMUM_RELEASE_AGE_SECONDS" ] \
            || die 'force is only allowed before the 14-day cooling period ends'
        SELECTION_REASON="explicitly requested $REQUESTED_RELEASE with force; 14-day cooling period waived"
    else
        [ "$release_age_seconds" -ge "$MINIMUM_RELEASE_AGE_SECONDS" ] \
            || die 'release is less than 14 days old; use -f only for an approved release'
        SELECTION_REASON="explicitly requested age-eligible immutable stable $REQUESTED_RELEASE"
    fi
}

attest_path() {
    local path record signer source subjects

    path=$1
    record=$(gh attestation verify "$path" \
        --repo "$REPOSITORY" \
        --hostname "$GITHUB_HOST" \
        --signer-workflow "$SIGNER_WORKFLOW" \
        --format json \
        --jq '
        .[0].verificationResult as $result
        | [
            $result.signature.certificate.buildSignerURI,
            $result.signature.certificate.sourceRepositoryURI,
            ([$result.statement.subject[].name] | join(","))
          ]
        | @tsv
    ')
    IFS=$'\t' read -r signer source subjects <<< "$record"

    case "$signer" in
        "$SIGNER_PREFIX"*) ATTESTED_TAG=${signer#"$SIGNER_PREFIX"} ;;
        *) die "unexpected attestation signer for $path: $signer" ;;
    esac
    [ "$source" = "$SOURCE_REPOSITORY" ] || die "unexpected attestation source for $path: $source"

    printf '  Subjects: %s\n' "$subjects"
    printf '  Signer: %s\n' "$signer"
    printf '  Source: %s\n' "$source"
}

verify_binary_paths() {
    local expected_tag index

    expected_tag=${1:-}
    INSTALLED_TAG=
    printf '\nBinary attestations:\n'
    for index in "${!BINARIES[@]}"; do
        printf '%s (%s):\n' "${BINARIES[$index]}" "${BINARY_PATHS[$index]}"
        attest_path "${BINARY_PATHS[$index]}"
        if [ -z "$INSTALLED_TAG" ]; then
            INSTALLED_TAG=$ATTESTED_TAG
        elif [ "$ATTESTED_TAG" != "$INSTALLED_TAG" ]; then
            die "Foundry binaries come from different releases: $INSTALLED_TAG and $ATTESTED_TAG"
        fi
    done

    if [ -n "$expected_tag" ] && [ "$INSTALLED_TAG" != "$expected_tag" ]; then
        die "installed Foundry release $INSTALLED_TAG does not match expected release $expected_tag"
    fi
}

run_binary_versions() {
    local path version_output

    printf '\nInstalled versions:\n'
    for path in "${BINARY_PATHS[@]}"; do
        if ! version_output=$("$path" --version); then
            die "could not read version from $path"
        fi
        [ -n "$version_output" ] || die "empty version output from $path"
        printf '%s\n' "$version_output"
    done
}

resolve_path_binaries() {
    local binary path

    BINARY_PATHS=()
    for binary in "${BINARIES[@]}"; do
        path=$(command -v "$binary" 2>/dev/null) || die "Foundry binary not found in PATH: $binary"
        [ -f "$path" ] && [ -x "$path" ] || die "Foundry command is not an executable file: $path"
        BINARY_PATHS+=("$path")
    done
}

validate_installed_release() {
    local record installed_published_at installed_draft installed_prerelease installed_immutable

    [[ "$INSTALLED_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "installed Foundry release does not use a stable version tag: $INSTALLED_TAG"
    if [ -n "$REQUESTED_RELEASE" ]; then
        [ "$INSTALLED_TAG" = "$VERSION" ] \
            || die "installed Foundry release $INSTALLED_TAG does not match requested release $VERSION"
        if [ "$FORCE_RELEASE" -eq 1 ]; then
            VERSION_STATUS="installed release matches explicitly requested forced immutable stable $VERSION"
        else
            VERSION_STATUS="installed release matches explicitly requested age-eligible immutable stable $VERSION"
        fi
        return
    fi
    record=$(gh api "repos/${REPOSITORY}/releases/tags/${INSTALLED_TAG}" --hostname "$GITHUB_HOST" \
        --jq '[.tag_name, .published_at, .draft, .prerelease, .immutable] | @tsv') || die "could not find Foundry release metadata for $INSTALLED_TAG"
    IFS=$'\t' read -r _ installed_published_at installed_draft installed_prerelease installed_immutable <<< "$record"
    [ "$installed_draft" = false ] && [ "$installed_prerelease" = false ] \
        || die "installed Foundry release is not stable: $INSTALLED_TAG"
    [ "$installed_immutable" = true ] || die "installed Foundry release is not immutable: $INSTALLED_TAG"

    if [ "$INSTALLED_TAG" = "$VERSION" ]; then
        VERSION_STATUS="installed release matches eligible immutable stable $VERSION"
    elif [ "$(printf '%s\n%s\n' "$installed_published_at" "$PUBLISHED_AT" | sort -r | sed -n '1p')" = "$installed_published_at" ]; then
        die "installed Foundry release $INSTALLED_TAG violates the 14-day policy; eligible release is $VERSION"
    else
        die "installed Foundry release $INSTALLED_TAG does not match newest eligible immutable stable $VERSION"
    fi
}

report_selection() {
    printf 'Desired Foundry release: %s\n' "$VERSION"
    printf 'Published at: %s\n' "$PUBLISHED_AT"
    printf 'Release URL: %s\n' "$RELEASE_URL"
    printf 'Selection policy: %s\n' "$SELECTION_REASON"
    printf 'spells-mainnet commit: %s\n' "$SOURCE_COMMIT"
    printf 'Setup CLI SHA-256: %s\n' "$CLI_SHA256"
}

report_verification_summary() {
    printf '\nEvidence summary:\n'
    printf '  Source: spells-mainnet %s; setup CLI SHA-256 %s\n' "$SOURCE_COMMIT" "$CLI_SHA256"
    printf '  Desired release: %s; %s; %s\n' "$VERSION" "$PUBLISHED_AT" "$RELEASE_URL"
    printf '  Policy decision: %s\n' "$SELECTION_REASON"
    printf '  Installed release: %s; %s\n' "$INSTALLED_TAG" "$VERSION_STATUS"
    printf '  Binary attestations: forge, cast, anvil, and chisel verified against %s\n' "$SIGNER_WORKFLOW"
}

rollback_installation() {
    local binary rollback_failed

    rollback_failed=0
    printf '\nInstallation did not complete; restoring the previous Foundry binaries.\n' >&2
    for binary in "${BINARIES[@]}"; do
        if ! rm -f "${DESTINATION}/${binary}"; then
            printf 'Rollback error: could not remove %s\n' "${DESTINATION}/${binary}" >&2
            rollback_failed=1
            continue
        fi
        if [ -e "${BACKUP_DIR}/${binary}" ] || [ -L "${BACKUP_DIR}/${binary}" ]; then
            if ! cp -pP "${BACKUP_DIR}/${binary}" "${DESTINATION}/${binary}"; then
                printf 'Rollback error: could not restore %s\n' "${DESTINATION}/${binary}" >&2
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
}

cleanup() {
    local exit_status=$?

    trap - EXIT INT TERM
    set +e
    if [ "$ROLLBACK_REQUIRED" -eq 1 ]; then
        rollback_installation
    fi
    if ! rm -rf "$TEMP_DIR"; then
        printf 'Cleanup error: could not remove temporary directory %s\n' "$TEMP_DIR" >&2
    fi
    exit "$exit_status"
}

initialize_installation() {
    RELEASE_ASSET="foundry_${VERSION}_${PLATFORM}_${ARCH}.tar.gz"
    DESTINATION="${HOME}/.foundry/bin"
    TEMP_DIR=$(mktemp -d)
    BACKUP_DIR="${TEMP_DIR}/previous-installation"
    ROLLBACK_REQUIRED=0
    DESTINATION_CREATED=0
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

download_verify_and_extract_release() {
    gh release download "$VERSION" --repo "$QUALIFIED_REPOSITORY" --pattern "$RELEASE_ASSET" --dir "$TEMP_DIR"
    printf '\nRelease asset attestation:\n'
    attest_path "${TEMP_DIR}/${RELEASE_ASSET}"
    [ "$ATTESTED_TAG" = "$VERSION" ] || die "release asset attestation tag $ATTESTED_TAG does not match $VERSION"

    EXTRACTED_DIR="${TEMP_DIR}/extracted"
    mkdir "$EXTRACTED_DIR"
    tar -xzf "${TEMP_DIR}/${RELEASE_ASSET}" -C "$EXTRACTED_DIR" "${BINARIES[@]}"
}

prepare_destination() {
    local binary

    # Reuse an existing directory, including a symlink to one, but reject files and broken links.
    # Track a missing destination so rollback can remove the directory created by this run.
    if [ -e "$DESTINATION" ] || [ -L "$DESTINATION" ]; then
        [ -d "$DESTINATION" ] || die "installation destination is not a directory: $DESTINATION"
    else
        DESTINATION_CREATED=1
    fi

    mkdir -m 0700 "$BACKUP_DIR"
    for binary in "${BINARIES[@]}"; do
        if [ -e "${DESTINATION}/${binary}" ] || [ -L "${DESTINATION}/${binary}" ]; then
            if [ ! -f "${DESTINATION}/${binary}" ] && [ ! -L "${DESTINATION}/${binary}" ]; then
                die "existing Foundry path is not a file or symbolic link: ${DESTINATION}/${binary}"
            fi
            cp -pP "${DESTINATION}/${binary}" "${BACKUP_DIR}/${binary}"
        fi
    done
}

install_binaries() {
    local binary

    ROLLBACK_REQUIRED=1
    if [ "$DESTINATION_CREATED" -eq 1 ]; then
        install -d -m 0755 "$DESTINATION"
    fi
    for binary in "${BINARIES[@]}"; do
        install -m 0755 "${EXTRACTED_DIR}/${binary}" "${DESTINATION}/${binary}"
    done
}

verify_installed_binaries() {
    local binary

    BINARY_PATHS=()
    for binary in "${BINARIES[@]}"; do
        BINARY_PATHS+=("${DESTINATION}/${binary}")
    done
    verify_binary_paths "$VERSION"
    run_binary_versions
    ROLLBACK_REQUIRED=0
}

finalize_installation() {
    printf '\nEvidence summary:\n'
    printf '  Source: spells-mainnet %s; setup CLI SHA-256 %s\n' "$SOURCE_COMMIT" "$CLI_SHA256"
    printf '  Release: %s; %s; %s\n' "$VERSION" "$PUBLISHED_AT" "$RELEASE_URL"
    printf '  Policy decision: %s\n' "$SELECTION_REASON"
    printf '  Release asset attestation: verified against %s\n' "$SIGNER_WORKFLOW"
    printf '  Binary attestations: forge, cast, anvil, and chisel verified against %s\n' "$SIGNER_WORKFLOW"

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
}

verify_foundry() {
    validate_environment
    collect_source_metadata
    if [ "$FORCE_RELEASE" -eq 1 ]; then
        load_requested_release
    else
        select_release
    fi
    report_selection
    INSTALL_REMEDIATION=1
    resolve_path_binaries
    verify_binary_paths
    validate_installed_release
    run_binary_versions
    report_verification_summary
    printf '\nFoundry verification completed successfully.\n'
}

install_foundry() {
    validate_environment
    validate_install_platform
    collect_source_metadata
    load_requested_release
    initialize_installation
    report_selection
    download_verify_and_extract_release
    prepare_destination
    install_binaries
    verify_installed_binaries
    finalize_installation
}

main() {
    local command option

    [ "$#" -ge 1 ] || { usage; exit 1; }
    command=$1
    shift
    while getopts ':fr:' option; do
        case "$option" in
            f) FORCE_RELEASE=1 ;;
            r) [ -n "$OPTARG" ] || { usage; exit 1; }; REQUESTED_RELEASE=$OPTARG ;;
            :) usage; exit 1 ;;
            \?) usage; exit 1 ;;
        esac
    done
    shift "$((OPTIND - 1))"
    [ "$#" -eq 0 ] || { usage; exit 1; }
    case "$command" in
        verify)
            if { [ -n "$REQUESTED_RELEASE" ] && [ "$FORCE_RELEASE" -eq 0 ]; } \
                || { [ -z "$REQUESTED_RELEASE" ] && [ "$FORCE_RELEASE" -eq 1 ]; }; then
                usage
                exit 1
            fi
            verify_foundry
            ;;
        install)
            [ -n "$REQUESTED_RELEASE" ] || { usage; exit 1; }
            install_foundry
            ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"
