#!/usr/bin/env bash
# Select, verify, or install an age-eligible stable Foundry release from GitHub.com.
# GitHub.com and Foundry's official release workflow are the pinned trust roots.
# Installed binaries are verified before execution; installation failures restore prior binaries.

set -euo pipefail

GITHUB_HOST="github.com"
REPOSITORY="foundry-rs/foundry"
QUALIFIED_REPOSITORY="${GITHUB_HOST}/${REPOSITORY}"
SIGNER_WORKFLOW="${REPOSITORY}/.github/workflows/release.yml"
SIGNER_PREFIX="https://${GITHUB_HOST}/${SIGNER_WORKFLOW}@refs/tags/"
SOURCE_REPOSITORY="https://${GITHUB_HOST}/${REPOSITORY}"
MINIMUM_RELEASE_AGE_SECONDS="1209600"
MINIMUM_RELEASE_AGE_DAYS=$((MINIMUM_RELEASE_AGE_SECONDS / 86400))
BINARIES=("forge" "cast" "anvil" "chisel")
SUPPORTED_ARCHIVE_TARGETS=("linux_amd64" "linux_arm64" "darwin_amd64" "darwin_arm64")
REQUESTED_RELEASE=
IGNORE_RELEASE_AGE=0
ARCHIVE_PREFLIGHT_STATUS=

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

die_installation_required() {
    printf 'Error: %s\n' "$*" >&2
    printf 'Required action: install\n' >&2
    printf 'Installation command: make install-foundry release=%s' "$VERSION" >&2
    if [ "$IGNORE_RELEASE_AGE" -eq 1 ]; then
        printf ' ignore-age=1' >&2
    fi
    printf '\n' >&2
    exit 1
}

usage() {
    local name

    name=${0##*/}
    cat <<EOF
NAME
    $name - select, verify, or install a policy-compliant Foundry release

SYNOPSIS
    $name COMMAND [OPTION...]
    $name --help

DESCRIPTION
    Selects, verifies, or installs immutable stable Foundry releases using the
    repository's release-age and artifact-attestation policy.

COMMANDS
    select
        Select and report a release after archive-attestation availability checks.

    verify
        Verify the Foundry binaries resolved from PATH against an exact release.

    install
        Install an explicitly requested release in \$HOME/.foundry/bin, replacing
        any existing Foundry binaries there.

OPTIONS
    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    $name select
    $name install --release v1.7.1
    $name verify --release v1.7.1
EOF
}

usage_select() {
    local name

    name=${0##*/}
    cat <<EOF
NAME
    $name select - select an installable Foundry release

SYNOPSIS
    $name select [--ignore-age]

DESCRIPTION
    Selects and reports the newest immutable stable Foundry release whose
    supported archives publish SHA-256 digests and SLSA provenance attestations.
    Does not download artifacts or resolve, attest, or execute installed Foundry
    binaries.

OPTIONS
    --ignore-age
        Select the newest immutable stable release without enforcing the ${MINIMUM_RELEASE_AGE_DAYS}-day
        cooling period. No other metadata requirement is bypassed.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation or policy check did not complete successfully.

EXAMPLES
    $name select
    $name select --ignore-age
EOF
}

usage_verify() {
    local name

    name=${0##*/}
    cat <<EOF
NAME
    $name verify - verify a policy-compliant Foundry release

SYNOPSIS
    $name verify --release RELEASE [--ignore-age]

DESCRIPTION
    Verifies the Foundry binaries resolved from PATH against an exact immutable
    stable release.

OPTIONS
    --release RELEASE
        Verify an exact immutable stable release. This option is required. The
        ${MINIMUM_RELEASE_AGE_DAYS}-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than ${MINIMUM_RELEASE_AGE_DAYS} days. Requires
        --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, or verification did not complete
            successfully.

EXAMPLES
    $name verify --release v1.7.0
    $name verify --release v1.7.1 --ignore-age
EOF
}

usage_install() {
    local name

    name=${0##*/}
    cat <<EOF
NAME
    $name install - install a policy-compliant Foundry release

SYNOPSIS
    $name install --release RELEASE [--ignore-age]

DESCRIPTION
    Downloads and installs an explicitly requested release in \$HOME/.foundry/bin,
    replacing any existing Foundry binaries there.

OPTIONS
    --release RELEASE
        Install an exact immutable stable release. This option is required. The
        ${MINIMUM_RELEASE_AGE_DAYS}-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than ${MINIMUM_RELEASE_AGE_DAYS} days. Requires
        --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    $name install --release v1.7.1
    $name install --release v1.7.1 --ignore-age
EOF
}

usage_error() {
    local message usage_function

    message=$1
    usage_function=${2:-usage}
    printf 'Error: %s\n\n' "$message" >&2
    "$usage_function" >&2
    exit 1
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@" | sed 's/[[:space:]].*$//'
    else
        LC_ALL=C shasum -a 256 "$@" | sed 's/[[:space:]].*$//'
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
    local script_path script_dir repo_root repo_script_path committed_cli_sha256

    script_path=${BASH_SOURCE[0]}
    script_dir=$(cd "$(dirname "$script_path")" && pwd)
    script_path="${script_dir}/${script_path##*/}"
    repo_root=$(git -C "${script_dir}/../.." rev-parse --show-toplevel 2>/dev/null) || die 'setup CLI is not in a Git checkout'
    case "$script_path" in
        "$repo_root"/*) repo_script_path=${script_path#"$repo_root"/} ;;
        *) die 'setup CLI is outside its Git checkout' ;;
    esac
    SOURCE_COMMIT=$(git -C "$repo_root" rev-parse HEAD)
    CLI_SHA256=$(sha256 "$script_path")
    committed_cli_sha256=$(git -C "$repo_root" show "${SOURCE_COMMIT}:${repo_script_path}" 2>/dev/null | sha256) \
        || die 'setup CLI is not tracked in HEAD'
    [ "$CLI_SHA256" = "$committed_cli_sha256" ] \
        || die 'setup CLI differs from HEAD; commit or restore it before continuing'
}

preflight_release_archives() {
    local archive_records asset asset_digest asset_matches attestation_count candidate_digest candidate_name target

    archive_records=$(gh api "repos/${REPOSITORY}/releases/tags/${VERSION}" --hostname "$GITHUB_HOST" \
        --jq '.assets[] | [.name, (.digest // "")] | @tsv') || {
        printf 'Skipping Foundry release %s: could not load release assets\n' "$VERSION" >&2
        return 1
    }

    for target in "${SUPPORTED_ARCHIVE_TARGETS[@]}"; do
        asset="foundry_${VERSION}_${target}.tar.gz"
        asset_digest=
        asset_matches=0
        while IFS=$'\t' read -r candidate_name candidate_digest; do
            if [ "$candidate_name" = "$asset" ]; then
                asset_matches=$((asset_matches + 1))
                asset_digest=$candidate_digest
            fi
        done <<< "$archive_records"

        if [ "$asset_matches" -ne 1 ]; then
            printf 'Skipping Foundry release %s: expected exactly one release asset named %s\n' "$VERSION" "$asset" >&2
            return 1
        fi
        if [[ ! "$asset_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
            printf 'Skipping Foundry release %s: release asset has no valid SHA-256 digest: %s\n' "$VERSION" "$asset" >&2
            return 1
        fi
        attestation_count=$(gh api \
            "repos/${REPOSITORY}/attestations/${asset_digest}?per_page=1&predicate_type=https%3A%2F%2Fslsa.dev%2Fprovenance%2Fv1" \
            --hostname "$GITHUB_HOST" \
            --jq '.attestations | length') || {
            printf 'Skipping Foundry release %s: could not load SLSA attestations for %s\n' "$VERSION" "$asset" >&2
            return 1
        }
        if [[ ! "$attestation_count" =~ ^[1-9][0-9]*$ ]]; then
            printf 'Skipping Foundry release %s: no SLSA attestation is published for %s\n' "$VERSION" "$asset" >&2
            return 1
        fi
    done

    ARCHIVE_PREFLIGHT_STATUS='SHA-256 digests and SLSA attestations published for all supported archives'
}

select_release() {
    local candidate_records minimum_age_seconds release_age_seconds selected

    minimum_age_seconds=$MINIMUM_RELEASE_AGE_SECONDS
    if [ "$IGNORE_RELEASE_AGE" -eq 1 ]; then
        minimum_age_seconds=0
    fi
    candidate_records=$(gh api --paginate "repos/${REPOSITORY}/releases?per_page=100" --hostname "$GITHUB_HOST" \
        --jq ".[] | select(.draft == false and .prerelease == false and .immutable == true and (.tag_name | test(\"^v[0-9]+\\\\.[0-9]+\\\\.[0-9]+$\")) and (now - (.published_at | fromdateiso8601)) >= ${minimum_age_seconds}) | [.tag_name, .published_at, .html_url, ((now - (.published_at | fromdateiso8601)) | floor)] | @tsv" \
        | sort -k2,2r) || die 'could not load stable Foundry release metadata'
    if [ "$IGNORE_RELEASE_AGE" -eq 1 ]; then
        [ -n "$candidate_records" ] || die 'no immutable stable Foundry release was found'
    else
        [ -n "$candidate_records" ] || die "no immutable stable Foundry release published at least ${MINIMUM_RELEASE_AGE_DAYS} days ago was found"
    fi
    selected=0
    while IFS=$'\t' read -r VERSION PUBLISHED_AT RELEASE_URL release_age_seconds; do
        if preflight_release_archives; then
            selected=1
            break
        fi
    done <<< "$candidate_records"
    [ "$selected" -eq 1 ] || die 'no immutable stable Foundry release passed archive preflight'
    if [ "$IGNORE_RELEASE_AGE" -eq 1 ] && [ "$release_age_seconds" -lt "$MINIMUM_RELEASE_AGE_SECONDS" ]; then
        SELECTION_REASON="newest immutable stable release; ${MINIMUM_RELEASE_AGE_DAYS}-day cooling period waived with --ignore-age"
    elif [ "$IGNORE_RELEASE_AGE" -eq 1 ]; then
        SELECTION_REASON='newest immutable stable release; release is age-eligible'
    else
        SELECTION_REASON="newest immutable stable release published at least ${MINIMUM_RELEASE_AGE_DAYS} days ago"
    fi
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
    if [ "$release_age_seconds" -ge "$MINIMUM_RELEASE_AGE_SECONDS" ]; then
        SELECTION_REASON="explicitly requested immutable stable $REQUESTED_RELEASE; release is age-eligible"
    elif [ "$IGNORE_RELEASE_AGE" -eq 1 ]; then
        SELECTION_REASON="explicitly requested immutable stable $REQUESTED_RELEASE; ${MINIMUM_RELEASE_AGE_DAYS}-day cooling period waived with --ignore-age"
    else
        die "release is less than ${MINIMUM_RELEASE_AGE_DAYS} days old; use --ignore-age only for an approved release"
    fi
}

attest_path() {
    local path digest record signer source subject

    path=$1
    digest=$(sha256 "$path")
    record=$(gh attestation verify "$path" \
        --repo "$REPOSITORY" \
        --hostname "$GITHUB_HOST" \
        --signer-workflow "$SIGNER_WORKFLOW" \
        --format json \
        --jq '
        .[0].verificationResult as $result
        | ($result.statement.subject[] | select(.digest.sha256 == "'"$digest"'")) as $subject
        | [
            $result.signature.certificate.buildSignerURI,
            $result.signature.certificate.sourceRepositoryURI,
            $subject.name
          ]
        | @tsv
    ') || die "could not verify attestation for $path"
    IFS=$'\t' read -r signer source subject <<< "$record"

    case "$signer" in
        "$SIGNER_PREFIX"*) ATTESTED_TAG=${signer#"$SIGNER_PREFIX"} ;;
        *) die "unexpected attestation signer for $path: $signer" ;;
    esac
    [ "$source" = "$SOURCE_REPOSITORY" ] || die "unexpected attestation source for $path: $source"
    case "$path" in
        "$subject" | *"/$subject") ;;
        *) die "attestation subject does not match path: $subject ($path)" ;;
    esac

    printf '  Subject: %s\n' "$subject"
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
        path=$(command -v "$binary" 2>/dev/null) || die_installation_required "Foundry binary not found in PATH: $binary"
        [ -f "$path" ] && [ -x "$path" ] || die "Foundry command is not an executable file: $path"
        BINARY_PATHS+=("$path")
    done
}

validate_installed_release() {
    if [ "$INSTALLED_TAG" != "$VERSION" ]; then
        die_installation_required "installed Foundry release $INSTALLED_TAG does not match requested release $VERSION"
    fi
    VERSION_STATUS="installed release matches explicitly requested immutable stable $VERSION"
}

report_selection() {
    printf 'Desired Foundry release: %s\n' "$VERSION"
    printf 'Published at: %s\n' "$PUBLISHED_AT"
    printf 'Release URL: %s\n' "$RELEASE_URL"
    printf 'Selection policy: %s\n' "$SELECTION_REASON"
    if [ -n "$ARCHIVE_PREFLIGHT_STATUS" ]; then
        printf 'Archive preflight: %s\n' "$ARCHIVE_PREFLIGHT_STATUS"
    fi
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
    if [ "$DESTINATION_PARENT_CREATED" -eq 1 ] && { [ -e "${DESTINATION%/*}" ] || [ -L "${DESTINATION%/*}" ]; }; then
        if ! rmdir "${DESTINATION%/*}"; then
            printf 'Rollback error: could not remove newly created directory %s\n' "${DESTINATION%/*}" >&2
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
    TEMP_DIR=$(mktemp -d)
    BACKUP_DIR="${TEMP_DIR}/previous-installation"
    ROLLBACK_REQUIRED=0
    DESTINATION_CREATED=0
    DESTINATION_PARENT_CREATED=0
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
        if [ ! -e "${DESTINATION%/*}" ] && [ ! -L "${DESTINATION%/*}" ]; then
            DESTINATION_PARENT_CREATED=1
        fi
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

report_path_action() {
    case ":$PATH:" in
        *":$DESTINATION:"*) ;;
        *)
            printf '\nFoundry is verified in %s, but that directory is not in PATH.\n' "$DESTINATION" >&2
            printf 'Required action: update-path\n' >&2
            printf '%s\n' 'Run: export PATH="$HOME/.foundry/bin:$PATH"' >&2
            printf '%s\n' 'Add the same export to your shell profile, then start a new shell before continuing.' >&2
            ;;
    esac
}

finalize_installation() {
    printf '\nEvidence summary:\n'
    printf '  Source: spells-mainnet %s; setup CLI SHA-256 %s\n' "$SOURCE_COMMIT" "$CLI_SHA256"
    printf '  Release: %s; %s; %s\n' "$VERSION" "$PUBLISHED_AT" "$RELEASE_URL"
    printf '  Policy decision: %s\n' "$SELECTION_REASON"
    printf '  Release asset attestation: verified against %s\n' "$SIGNER_WORKFLOW"
    printf '  Binary attestations: forge, cast, anvil, and chisel verified against %s\n' "$SIGNER_WORKFLOW"

    report_path_action
    printf '\nFoundry installation and verification completed successfully.\n'
}

verify_foundry() {
    validate_environment
    collect_source_metadata
    load_requested_release
    report_selection
    resolve_path_binaries
    verify_binary_paths
    validate_installed_release
    run_binary_versions
    report_verification_summary
    printf '\nFoundry verification completed successfully.\n'
}

select_foundry() {
    validate_environment
    collect_source_metadata
    select_release
    report_selection
    printf '\nFoundry release selection completed successfully.\n'
}

install_foundry() {
    validate_environment
    validate_install_platform
    collect_source_metadata
    load_requested_release
    DESTINATION="${HOME}/.foundry/bin"
    report_selection
    initialize_installation
    download_verify_and_extract_release
    prepare_destination
    install_binaries
    verify_installed_binaries
    finalize_installation
}

main() {
    local command command_usage

    [ "$#" -ge 1 ] || usage_error 'command is required'
    if [ "$1" = --help ]; then
        [ "$#" -eq 1 ] || usage_error '--help cannot be combined with other arguments'
        usage
        exit 0
    fi
    command=$1
    case "$command" in
        select | verify | install) ;;
        *) usage_error "unknown command: $command" ;;
    esac
    command_usage="usage_$command"
    shift
    if [ "$#" -gt 0 ] && [ "$1" = --help ]; then
        [ "$#" -eq 1 ] || usage_error '--help cannot be combined with other arguments' "$command_usage"
        "$command_usage"
        exit 0
    fi
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --ignore-age)
                IGNORE_RELEASE_AGE=1
                shift
                ;;
            --release)
                [ "$command" != select ] || usage_error 'select does not accept --release' "$command_usage"
                [ "$#" -ge 2 ] && [ -n "$2" ] || usage_error '--release requires a value' "$command_usage"
                case "$2" in
                    --*) usage_error '--release requires a value' "$command_usage" ;;
                esac
                REQUESTED_RELEASE=$2
                shift 2
                ;;
            --release=*)
                [ "$command" != select ] || usage_error 'select does not accept --release' "$command_usage"
                REQUESTED_RELEASE=${1#--release=}
                [ -n "$REQUESTED_RELEASE" ] || usage_error '--release requires a value' "$command_usage"
                shift
                ;;
            --help)
                usage_error '--help cannot be combined with other arguments' "$command_usage"
                ;;
            --)
                shift
                break
                ;;
            -*) usage_error "unknown option: $1" "$command_usage" ;;
            *) usage_error "unexpected argument: $1" "$command_usage" ;;
        esac
    done
    [ "$#" -eq 0 ] || usage_error "unexpected argument: $1" "$command_usage"
    if { [ "$command" = verify ] || [ "$command" = install ]; } && [ -z "$REQUESTED_RELEASE" ]; then
        usage_error "$command requires --release" "$command_usage"
    fi
    case "$command" in
        select) select_foundry ;;
        verify) verify_foundry ;;
        install) install_foundry ;;
    esac
}

main "$@"
