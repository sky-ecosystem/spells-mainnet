#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CLI="$ROOT/scripts/setup-foundry/setup-foundry.sh"
BASH_PATH=$(command -v bash)
JQ_PATH=$(command -v jq) || {
    printf 'test prerequisite not found: jq\n' >&2
    exit 1
}
export ROOT CLI JQ_PATH
PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'not ok - %s\n' "$1"
}

expected_top_level_usage() {
    cat <<'EOF'
NAME
    setup-foundry.sh - select, verify, or install a policy-compliant Foundry release

SYNOPSIS
    setup-foundry.sh COMMAND [OPTION...]
    setup-foundry.sh --help

DESCRIPTION
    Selects, verifies, or installs immutable stable Foundry releases using the
    repository's release-age and artifact-attestation policy.

COMMANDS
    select
        Select and report a release using metadata only.

    verify
        Verify the Foundry binaries resolved from PATH against an exact release.

    install
        Verify or install an explicitly requested release in $HOME/.foundry/bin.

OPTIONS
    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    setup-foundry.sh select --help
    setup-foundry.sh verify --help
    setup-foundry.sh install --help
EOF
}

expected_select_usage() {
    cat <<'EOF'
NAME
    setup-foundry.sh select - select a Foundry release using metadata only

SYNOPSIS
    setup-foundry.sh select [--ignore-age]

DESCRIPTION
    Selects and reports the newest immutable stable Foundry release without
    resolving, attesting, or executing installed Foundry binaries.

OPTIONS
    --ignore-age
        Select the newest immutable stable release without enforcing the 14-day
        cooling period. No other metadata requirement is bypassed.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation or policy check did not complete successfully.

EXAMPLES
    setup-foundry.sh select
    setup-foundry.sh select --ignore-age
EOF
}

expected_verify_usage() {
    cat <<'EOF'
NAME
    setup-foundry.sh verify - verify a policy-compliant Foundry release

SYNOPSIS
    setup-foundry.sh verify --release RELEASE [--ignore-age]

DESCRIPTION
    Verifies the Foundry binaries resolved from PATH against an exact immutable
    stable release.

OPTIONS
    --release RELEASE
        Verify an exact immutable stable release. This option is required. The
        14-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than 14 days. Requires
        --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, or verification did not complete
            successfully.

EXAMPLES
    setup-foundry.sh verify --release v1.7.0
    setup-foundry.sh verify --release v1.7.1 --ignore-age
EOF
}

expected_install_usage() {
    cat <<'EOF'
NAME
    setup-foundry.sh install - install a policy-compliant Foundry release

SYNOPSIS
    setup-foundry.sh install --release RELEASE [--ignore-age]

DESCRIPTION
    Verifies an explicitly requested release in $HOME/.foundry/bin, or downloads
    and installs it when the existing destination does not match.

OPTIONS
    --release RELEASE
        Install an exact immutable stable release. This option is required. The
        14-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than 14 days. Requires
        --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    setup-foundry.sh install --release v1.7.0
    setup-foundry.sh install --release v1.7.1 --ignore-age
EOF
}

apply_stub() {
    name=$1
    body=$2
    printf '%s\n' "$body" > "$FIXTURE/bin/$name"
    chmod +x "$FIXTURE/bin/$name"
}

new_fixture() {
    local young_published_at

    FIXTURE=$(mktemp -d)
    export FIXTURE
    export HOME="$FIXTURE/home"
    export TEST_LOG="$FIXTURE/log"
    export TEST_OS=${1:-Linux}
    export TEST_ARCH=${2:-x86_64}
    export TEST_ROSETTA=${3:-0}
    export TEST_NO_PREVIOUS=0
    export TEST_INSTALLED_TAG=v2.0.0
    export TEST_INSTALLED_IMMUTABLE=true
    export TEST_YOUNG_RELEASE_AGE_SECONDS=3600
    export TEST_REQUESTED_DRAFT=false
    export TEST_REQUESTED_PRERELEASE=false
    export TEST_MIXED_BINARY=
    export TEST_ATTEST_FAIL=
    export TEST_ATTEST_SUBJECT_NAME=
    export TEST_BINARY_ATTEST_STATUS=1
    export TEST_VERSION_FAIL=
    export TEST_AUTH_STATUS=0
    export TEST_RELEASE_LIST_STATUS=0
    export TEST_HEAD_CLI_MISMATCH=0
    mkdir -p "$HOME/.foundry/bin" "$FIXTURE/bin" "$FIXTURE/foundry-bin" "$TEST_LOG"

    young_published_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    cat > "$FIXTURE/releases.json" <<EOF
[
  {"tag_name":"v2.1.0","published_at":"$young_published_at","html_url":"https://example.test/v2.1.0","draft":false,"prerelease":false,"immutable":true},
  {"tag_name":"v1.9.0","published_at":"2001-01-01T00:00:00Z","html_url":"https://example.test/v1.9.0","draft":false,"prerelease":false,"immutable":true},
  {"tag_name":"v9.0.0","published_at":"2009-01-01T00:00:00Z","html_url":"https://example.test/v9.0.0","draft":true,"prerelease":false,"immutable":true},
  {"tag_name":"v8.0.0","published_at":"2008-01-01T00:00:00Z","html_url":"https://example.test/v8.0.0","draft":false,"prerelease":true,"immutable":true},
  {"tag_name":"v7.0.0","published_at":"2007-01-01T00:00:00Z","html_url":"https://example.test/v7.0.0","draft":false,"prerelease":false,"immutable":false},
  {"tag_name":"nightly-2006","published_at":"2006-01-01T00:00:00Z","html_url":"https://example.test/nightly-2006","draft":false,"prerelease":false,"immutable":true},
  {"tag_name":"v6.0.0","published_at":"2999-01-01T00:00:00Z","html_url":"https://example.test/v6.0.0","draft":false,"prerelease":false,"immutable":true},
  {"tag_name":"v2.0.0","published_at":"2002-01-01T00:00:00Z","html_url":"https://example.test/v2.0.0","draft":false,"prerelease":false,"immutable":true}
]
EOF
    cat > "$FIXTURE/releases-ineligible.json" <<'EOF'
[
  {"tag_name":"v3.0.0","published_at":"2003-01-01T00:00:00Z","html_url":"https://example.test/v3.0.0","draft":false,"prerelease":false,"immutable":false}
]
EOF

    apply_stub gh '#!/usr/bin/env bash
set -eu
printf "%s\n" "$*" >> "$TEST_LOG/gh"
if [ "$1 $2" = "auth status" ]; then exit "$TEST_AUTH_STATUS"; fi
if [ "$1" = api ] && [ "${2:-}" = "--paginate" ]; then
    [ "$TEST_RELEASE_LIST_STATUS" -eq 0 ] || exit "$TEST_RELEASE_LIST_STATUS"
    shift 2
    query=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --jq) query=$2; shift 2 ;;
            *) shift ;;
        esac
    done
    [ -n "$query" ] || exit 64
    if [ "${TEST_NO_PREVIOUS:-0}" = 1 ]; then
        releases=$FIXTURE/releases-ineligible.json
    else
        releases=$FIXTURE/releases.json
    fi
    "$JQ_PATH" -r "$query" "$releases"
    exit 0
fi
case "${2:-}" in
    repos/foundry-rs/foundry/releases/tags/*)
        tag=${2##*/}
        if [[ "$*" = *html_url* ]]; then
            case "$tag" in
                v2.1.0) printf "v2.1.0\t2026-07-21T00:00:00Z\thttps://example.test/v2.1.0\t%s\t%s\t%s\t%s\n" "$TEST_REQUESTED_DRAFT" "$TEST_REQUESTED_PRERELEASE" "$TEST_INSTALLED_IMMUTABLE" "$TEST_YOUNG_RELEASE_AGE_SECONDS" ;;
                v2.0.0) printf "v2.0.0\t2002-01-01T00:00:00Z\thttps://example.test/v2.0.0\tfalse\tfalse\t%s\t99999999\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                *) exit 1 ;;
            esac
        else
            case "$tag" in
                v2.1.0) printf "v2.1.0\t2026-07-21T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                v2.0.0) printf "v2.0.0\t2002-01-01T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                v2.0.0-rc1) printf "v2.0.0-rc1\t2001-12-01T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                v1.9.0) printf "v1.9.0\t2001-01-01T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                v1.8.0) printf "v1.8.0\t2000-01-01T00:00:00Z\tfalse\ttrue\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                v1.8.0-rc1) printf "v1.8.0-rc1\t1999-12-01T00:00:00Z\tfalse\ttrue\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
                *) exit 1 ;;
            esac
        fi
        exit 0
        ;;
esac
if [ "$1 $2" = "release download" ]; then
    version=$3
    shift 3
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --pattern) asset=$2; shift 2 ;;
            --dir) dir=$2; shift 2 ;;
            *) shift ;;
        esac
    done
    printf "%s\n" "$version" > "$TEST_LOG/download-version"
    : > "$dir/$asset"
    exit 0
fi
if [ "$1 $2" = "attestation verify" ]; then
    subject=$3
    name=${subject##*/}
    if [ -n "${TEST_ATTEST_FAIL:-}" ] && [ "$name" = "$TEST_ATTEST_FAIL" ]; then
        exit "${TEST_BINARY_ATTEST_STATUS:-1}"
    fi
    case "$name" in
        foundry_v*_*.tar.gz) tag=${name#foundry_}; tag=${tag%%_*} ;;
        *) tag=${TEST_INSTALLED_TAG:-v2.0.0} ;;
    esac
    if [ -n "${TEST_MIXED_BINARY:-}" ] && [ "$name" = "$TEST_MIXED_BINARY" ]; then
        tag=v1.9.0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        digest=$(sha256sum "$subject" | sed "s/[[:space:]].*$//")
    else
        digest=$(LC_ALL=C shasum -a 256 "$subject" | sed "s/[[:space:]].*$//")
    fi
    matching_name=${TEST_ATTEST_SUBJECT_NAME:-$name}
    payload=$("$JQ_PATH" -cn \
        --arg name "$matching_name" \
        --arg digest "$digest" \
        --arg tag "$tag" \
        "[{verificationResult:{statement:{subject:[
            {name:\"unrelated\",digest:{sha256:\"0000000000000000000000000000000000000000000000000000000000000000\"}},
            {name:\$name,digest:{sha256:\$digest}}
        ]},signature:{certificate:{
            buildSignerURI:(\"https://github.com/foundry-rs/foundry/.github/workflows/release.yml@refs/tags/\" + \$tag),
            sourceRepositoryURI:\"https://github.com/foundry-rs/foundry\"
        }}}}]")
    query=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --jq) query=$2; shift 2 ;;
            *) shift ;;
        esac
    done
    if [ -n "$query" ]; then
        printf "%s\n" "$payload" | "$JQ_PATH" -r "$query"
    else
        printf "%s\n" "$payload"
    fi
    exit 0
fi
exit 64'

    apply_stub uname '#!/usr/bin/env bash
case "${1:-}" in
    -s) printf "%s\n" "$TEST_OS" ;;
    -m) printf "%s\n" "$TEST_ARCH" ;;
    *) exit 64 ;;
esac'

    apply_stub sysctl '#!/usr/bin/env bash
if [ "${1:-} ${2:-}" = "-n sysctl.proc_translated" ]; then
    printf "%s\n" "$TEST_ROSETTA"
    exit 0
fi
exit 64'

    apply_stub git '#!/usr/bin/env bash
if [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse --show-toplevel" ]; then
    printf "%s\n" "$ROOT"
elif [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse HEAD" ]; then
    printf "0123456789abcdef0123456789abcdef01234567\n"
elif [ "$1" = "-C" ] && [ "$3" = "show" ] \
    && [ "$4" = "0123456789abcdef0123456789abcdef01234567:scripts/setup-foundry/setup-foundry.sh" ]; then
    if [ "$TEST_HEAD_CLI_MISMATCH" -eq 1 ]; then
        printf "modified setup CLI\n"
    else
        /bin/cat "$CLI"
    fi
else
    exit 64
fi'

    apply_stub tar '#!/usr/bin/env bash
set -eu
printf "%s\n" "$*" >> "$TEST_LOG/tar"
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-C" ]; then out=$2; shift 2; else shift; fi
done
for binary in forge cast anvil chisel; do
    {
        printf "#!/usr/bin/env bash\n"
        printf "printf \\\"%%s\\\\n\\\" \\\"%%s\\\" >> \\\"\\$TEST_LOG/versions\\\"\n" "$binary"
        printf "printf \\\"%%s\\\\n\\\" \\\"%%s Version: 2.0.0\\\"\n" "$binary"
    } > "$out/$binary"
    chmod +x "$out/$binary"
done'

    apply_stub install '#!/usr/bin/env bash
set -eu
printf "%s\n" "$*" >> "$TEST_LOG/install"
if [ "$1" = "-d" ]; then
    shift
    if [ "$1" = "-m" ]; then shift 2; fi
    mkdir -p "$1"
    exit 0
fi
if [ "$1" = "-m" ]; then shift 2; fi
cp "$1" "$2"
chmod 0755 "$2"'

    for binary in forge cast anvil chisel; do
        apply_stub "$binary" "#!/usr/bin/env bash
printf '%s\\n' '$binary' >> \"\$TEST_LOG/versions\"
if [ \"\${TEST_VERSION_FAIL:-}\" = '$binary' ]; then exit 17; fi
printf '%s\\n' '$binary Version: 2.0.0'"
        mv "$FIXTURE/bin/$binary" "$FIXTURE/foundry-bin/$binary"
    done
    mkdir -p "$FIXTURE/repository/scripts/setup-foundry"
}

run_cli() {
    path_mode=${1:-foundry-path}
    command=${2:-verify}
    [ "$#" -gt 0 ] && shift
    [ "$#" -gt 0 ] && shift
    if [ "$path_mode" = foundry-path ]; then
        PATH="$FIXTURE/foundry-bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" "$@" > "$FIXTURE/out" 2>&1
    elif [ "$path_mode" = destination-path ]; then
        PATH="$HOME/.foundry/bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" "$@" > "$FIXTURE/out" 2>&1
    else
        PATH="$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" "$@" > "$FIXTURE/out" 2>&1
    fi
    STATUS=$?
}

test_select_is_metadata_only() {
    new_fixture
    run_cli no-foundry select
    if [ "$STATUS" -eq 0 ] \
        && grep -q '^Desired Foundry release: v2.0.0$' "$FIXTURE/out" \
        && grep -q '^Selection policy: newest immutable stable release published at least 14 days ago$' "$FIXTURE/out" \
        && grep -q 'api --paginate' "$TEST_LOG/gh" \
        && ! grep -q '^attestation verify ' "$TEST_LOG/gh" \
        && [ ! -e "$TEST_LOG/versions" ] \
        && [ ! -e "$TEST_LOG/download-version" ]; then
        pass 'selection reports metadata without resolving or invoking Foundry binaries'
    else
        fail 'selection reports metadata without resolving or invoking Foundry binaries'
    fi
    rm -rf "$FIXTURE"
}

test_select_ignore_age_chooses_newest_stable_release() {
    new_fixture
    run_cli no-foundry select --ignore-age
    if [ "$STATUS" -eq 0 ] \
        && grep -q '^Desired Foundry release: v2.1.0$' "$FIXTURE/out" \
        && grep -q '^Selection policy: newest immutable stable release; 14-day cooling period waived with --ignore-age$' "$FIXTURE/out" \
        && [ ! -e "$TEST_LOG/versions" ]; then
        pass 'age-waived selection reports the newest immutable stable release'
    else
        fail 'age-waived selection reports the newest immutable stable release'
    fi
    rm -rf "$FIXTURE"
}

test_verify_requires_release() {
    new_fixture
    run_cli foundry-path verify
    if [ "$STATUS" -eq 1 ] \
        && grep -Fq 'Error: verify requires --release' "$FIXTURE/out" \
        && [ ! -e "$TEST_LOG/gh" ] \
        && [ ! -e "$TEST_LOG/versions" ]; then
        pass 'verify requires an explicit release before environment checks'
    else
        fail 'verify requires an explicit release before environment checks'
    fi
    rm -rf "$FIXTURE"
}

test_select_rejects_release() {
    new_fixture
    run_cli no-foundry select --release v2.0.0
    if [ "$STATUS" -eq 1 ] \
        && grep -Fq 'Error: select does not accept --release' "$FIXTURE/out" \
        && [ ! -e "$TEST_LOG/gh" ]; then
        pass 'select rejects an explicit release'
    else
        fail 'select rejects an explicit release'
    fi
    rm -rf "$FIXTURE"
}

test_make_select_forwards_ignore_age() {
    output=$(make -s -n -C "$ROOT" select-foundry ignore-age=1 2>&1)
    status=$?
    if [ "$status" -eq 0 ] && [[ "$output" = *'setup-foundry.sh select --ignore-age'* ]]; then
        pass 'Make selection forwards the age waiver'
    else
        fail 'Make selection forwards the age waiver'
    fi
}

test_verify_eligible() {
    new_fixture
    run_cli foundry-path verify --release v2.0.0
    attestations=$(grep -c '^attestation verify ' "$TEST_LOG/gh" 2>/dev/null || true)
    formatted_attestations=$(grep -c '^attestation verify .* --jq ' "$TEST_LOG/gh" 2>/dev/null || true)
    if [ -e "$TEST_LOG/versions" ]; then versions=$(wc -l < "$TEST_LOG/versions"); else versions=0; fi
    if [ "$STATUS" -eq 0 ] && [ "$attestations" -eq 4 ] && [ "$formatted_attestations" -eq 4 ] \
        && [ "$versions" -eq 4 ] \
        && [ "$(grep -c '^  Subject: ' "$FIXTURE/out" 2>/dev/null || true)" -eq 4 ] \
        && ! grep -q 'unrelated' "$FIXTURE/out" \
        && ! grep -q '^  Subjects:' "$FIXTURE/out" \
        && ! grep -q 'api --paginate' "$TEST_LOG/gh" \
        && grep -q 'Desired Foundry release: v2.0.0' "$FIXTURE/out" \
        && grep -q 'Selection policy: explicitly requested immutable stable v2.0.0; release is age-eligible' "$FIXTURE/out" \
        && grep -q 'Foundry verification completed successfully' "$FIXTURE/out"; then
        pass 'exact age-eligible immutable PATH toolchain is verified'
    else
        fail 'exact age-eligible immutable PATH toolchain is verified'
    fi
    rm -rf "$FIXTURE"
}

test_attestation_subject_must_match_verified_path() {
    new_fixture
    TEST_ATTEST_SUBJECT_NAME=renamed-forge
    export TEST_ATTEST_SUBJECT_NAME
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'attestation subject does not match path' "$FIXTURE/out"; then
        pass 'matching-digest attestation subject must match the verified path'
    else
        fail 'matching-digest attestation subject must match the verified path'
    fi
    rm -rf "$FIXTURE"
}

test_modified_cli_is_rejected_before_reporting_source_metadata() {
    new_fixture
    TEST_HEAD_CLI_MISMATCH=1
    export TEST_HEAD_CLI_MISMATCH
    run_cli foundry-path verify --release v2.0.0
    gh_calls=$(wc -l < "$TEST_LOG/gh")
    if [ "$STATUS" -eq 1 ] && [ "$gh_calls" -eq 1 ] \
        && grep -q 'setup CLI differs from HEAD' "$FIXTURE/out" \
        && ! grep -q '^Desired Foundry release:' "$FIXTURE/out" \
        && [ ! -e "$TEST_LOG/versions" ]; then
        pass 'modified setup CLI is rejected before source metadata is reported'
    else
        fail 'modified setup CLI is rejected before source metadata is reported'
    fi
    rm -rf "$FIXTURE"
}

test_shasum_fallback_forces_portable_locale() {
    new_fixture
    mkdir "$FIXTURE/fallback-bin"
    for command in bash dirname sed; do
        ln -s "$(command -v "$command")" "$FIXTURE/fallback-bin/$command"
    done
    apply_stub shasum '#!/usr/bin/env bash
printf "%s\n" "${LC_ALL:-}" >> "$TEST_LOG/shasum-locales"
[ "$#" -ne 2 ] || /bin/cat >/dev/null
printf "%s  %s\n" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "${3:-}"'

    LC_ALL=C.UTF-8 PATH="$FIXTURE/foundry-bin:$FIXTURE/bin:$FIXTURE/fallback-bin" \
        "$BASH_PATH" "$CLI" verify --release v2.0.0 > "$FIXTURE/out" 2>&1
    status=$?
    if [ -e "$TEST_LOG/shasum-locales" ]; then
        shasum_calls=$(wc -l < "$TEST_LOG/shasum-locales")
        non_c_calls=$(grep -vc '^C$' "$TEST_LOG/shasum-locales" || true)
    else
        shasum_calls=0
        non_c_calls=0
    fi

    if [ "$status" -eq 0 ] && [ "$shasum_calls" -eq 10 ] && [ "$non_c_calls" -eq 0 ]; then
        pass 'shasum fallback uses the portable C locale'
    else
        fail 'shasum fallback uses the portable C locale'
    fi
    rm -rf "$FIXTURE"
}

test_verify_rejects_mutable_release() {
    new_fixture
    TEST_INSTALLED_IMMUTABLE=false
    export TEST_INSTALLED_IMMUTABLE
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'is not immutable' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out"; then
        pass 'mutable requested release fails verification before execution'
    else
        fail 'mutable requested release fails verification before execution'
    fi
    rm -rf "$FIXTURE"
}

test_verify_replaces_nonrequired_prerelease() {
    new_fixture
    TEST_INSTALLED_TAG=v1.8.0; export TEST_INSTALLED_TAG
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q 'releases/tags/v1.8.0' "$TEST_LOG/gh" \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.0.0$' "$FIXTURE/out"; then
        pass 'non-required prerelease reports the exact install command without execution'
    else
        fail 'non-required prerelease reports the exact install command without execution'
    fi
    rm -rf "$FIXTURE"
}

test_verify_replaces_nonrequired_rc() {
    new_fixture
    TEST_INSTALLED_TAG=v2.0.0-rc1; export TEST_INSTALLED_TAG
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q 'releases/tags/v2.0.0-rc1' "$TEST_LOG/gh" \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.0.0$' "$FIXTURE/out"; then
        pass 'non-required RC reports the exact install command without execution'
    else
        fail 'non-required RC reports the exact install command without execution'
    fi
    rm -rf "$FIXTURE"
}

test_verify_reports_version_failure() {
    new_fixture
    TEST_VERSION_FAIL=cast; export TEST_VERSION_FAIL
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -eq 1 ] && grep -q 'could not read version from' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out"; then
        pass 'binary version failure has a useful diagnostic'
    else
        fail 'binary version failure has a useful diagnostic'
    fi
    rm -rf "$FIXTURE"
}

test_verify_older_fails() {
    new_fixture
    TEST_INSTALLED_TAG=v1.9.0; export TEST_INSTALLED_TAG
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q 'releases/tags/v1.9.0' "$TEST_LOG/gh" \
        && grep -q 'does not match requested release v2.0.0' "$FIXTURE/out" \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Desired Foundry release: v2.0.0$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.0.0$' "$FIXTURE/out"; then
        pass 'older verified stable release reports the exact install command'
    else
        fail 'older verified stable release reports the exact install command'
    fi
    rm -rf "$FIXTURE"
}

test_verify_newer_fails() {
    new_fixture
    TEST_INSTALLED_TAG=v2.1.0
    export TEST_INSTALLED_TAG
    run_cli foundry-path verify --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q 'releases/tags/v2.1.0' "$TEST_LOG/gh" \
        && grep -q 'does not match requested release v2.0.0' "$FIXTURE/out" \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.0.0$' "$FIXTURE/out"; then
        pass 'newer non-required release reports the exact install command'
    else
        fail 'newer non-required release reports the exact install command'
    fi
    rm -rf "$FIXTURE"
}

test_verify_rejects_missing_mixed_and_unattested() {
    ok=1

    new_fixture
    rm "$FIXTURE/foundry-bin/chisel"
    run_cli foundry-path verify --release v2.0.0
    [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.0.0$' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_MIXED_BINARY=cast; export TEST_MIXED_BINARY
    run_cli foundry-path verify --release v2.0.0
    [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q '^Required action:' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_ATTEST_FAIL=cast; export TEST_ATTEST_FAIL
    run_cli foundry-path verify --release v2.0.0
    [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && ! grep -q '^Required action:' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    if [ "$ok" -eq 1 ]; then
        pass 'only a missing toolchain requires installation'
    else
        fail 'only a missing toolchain requires installation'
    fi
}

test_verify_remote_failures_stop_without_installation() {
    ok=1

    new_fixture
    TEST_AUTH_STATUS=42; export TEST_AUTH_STATUS
    run_cli foundry-path verify --release v2.0.0
    [ "$STATUS" -eq 1 ] && ! grep -q '^Required action:' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_RELEASE_LIST_STATUS=42; export TEST_RELEASE_LIST_STATUS
    run_cli no-foundry select
    [ "$STATUS" -eq 1 ] && ! grep -q '^Required action:' "$FIXTURE/out" \
        && ! grep -q '^Installation command:' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    if [ "$ok" -eq 1 ]; then
        pass 'authentication and release API failures stop without installation'
    else
        fail 'authentication and release API failures stop without installation'
    fi
}

test_install_requires_release() {
    new_fixture
    run_cli destination-path install
    if [ "$STATUS" -eq 1 ] \
        && grep -Fq 'Error: install requires --release' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out" \
        && [ ! -e "$TEST_LOG/gh" ] \
        && [ ! -e "$TEST_LOG/download-version" ] \
        && [ ! -e "$TEST_LOG/install" ]; then
        pass 'install requires an explicit release before environment checks'
    else
        fail 'install requires an explicit release before environment checks'
    fi
    rm -rf "$FIXTURE"
}

test_install_skips_verified_matching_destination() {
    new_fixture
    for binary in forge cast anvil chisel; do
        cp "$FIXTURE/foundry-bin/$binary" "$HOME/.foundry/bin/$binary"
    done
    run_cli destination-path install --release v2.0.0
    attestations=$(grep -c '^attestation verify ' "$TEST_LOG/gh" 2>/dev/null || true)
    if [ -e "$TEST_LOG/versions" ]; then versions=$(wc -l < "$TEST_LOG/versions"); else versions=0; fi
    if [ "$STATUS" -eq 0 ] && [ "$attestations" -eq 4 ] && [ "$versions" -eq 4 ] \
        && [ ! -e "$TEST_LOG/download-version" ] && [ ! -e "$TEST_LOG/tar" ] && [ ! -e "$TEST_LOG/install" ] \
        && grep -q 'Foundry installation skipped: v2.0.0 is already installed and verified' "$FIXTURE/out" \
        && grep -q 'Installation: skipped; existing destination binaries match desired release' "$FIXTURE/out"; then
        pass 'install skips a verified matching destination without downloading or modifying files'
    else
        fail 'install skips a verified matching destination without downloading or modifying files'
    fi
    rm -rf "$FIXTURE"
}

test_select_without_eligible_release_fails() {
    new_fixture
    TEST_NO_PREVIOUS=1
    export TEST_NO_PREVIOUS
    run_cli no-foundry select
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/download-version" ] \
        && grep -q 'no immutable stable Foundry release published at least 14 days ago was found' "$FIXTURE/out"; then
        pass 'selection fails when no eligible immutable stable release exists'
    else
        fail 'selection fails when no eligible immutable stable release exists'
    fi
    rm -rf "$FIXTURE"
}

test_install_accepts_explicit_age_eligible_release() {
    new_fixture
    run_cli destination-path install --release v2.0.0
    if [ "$STATUS" -eq 0 ] && [ "$(cat "$TEST_LOG/download-version")" = v2.0.0 ] \
        && [ -x "$HOME/.foundry/bin/forge" ] \
        && ! grep -q 'api --paginate' "$TEST_LOG/gh"; then
        pass 'install executes the explicit age-eligible release without selecting one'
    else
        fail 'install executes the explicit age-eligible release without selecting one'
    fi
    rm -rf "$FIXTURE"
}

test_verify_accepts_requested_young_release() {
    new_fixture
    TEST_INSTALLED_TAG=v2.1.0
    export TEST_INSTALLED_TAG
    run_cli foundry-path verify --release=v2.1.0 --ignore-age
    if [ "$STATUS" -eq 0 ] \
        && grep -q 'Selection policy: explicitly requested immutable stable v2.1.0; 14-day cooling period waived with --ignore-age' "$FIXTURE/out" \
        && grep -q 'Installed release: v2.1.0' "$FIXTURE/out"; then
        pass 'explicit young release is verified with the age waiver reported'
    else
        fail 'explicit young release is verified with the age waiver reported'
    fi
    rm -rf "$FIXTURE"
}

test_install_accepts_requested_young_release() {
    new_fixture
    TEST_INSTALLED_TAG=v2.1.0
    export TEST_INSTALLED_TAG
    run_cli destination-path install --release v2.1.0 --ignore-age
    if [ "$STATUS" -eq 0 ] \
        && [ "$(cat "$TEST_LOG/download-version")" = v2.1.0 ] \
        && grep -q 'Policy decision: explicitly requested immutable stable v2.1.0; 14-day cooling period waived with --ignore-age' "$FIXTURE/out"; then
        pass 'explicit young release is installed with the age waiver reported'
    else
        fail 'explicit young release is installed with the age waiver reported'
    fi
    rm -rf "$FIXTURE"
}

test_young_release_requires_ignore_age() {
    ok=1

    new_fixture
    run_cli foundry-path verify --release v2.1.0
    [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'release is less than 14 days old; use --ignore-age only for an approved release' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    run_cli destination-path install --release v2.1.0
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/download-version" ] \
        && grep -q 'release is less than 14 days old; use --ignore-age only for an approved release' "$FIXTURE/out" \
        && [ "$ok" -eq 1 ]; then
        pass 'verify and install require --ignore-age for a young release'
    else
        fail 'verify and install require --ignore-age for a young release'
    fi
    rm -rf "$FIXTURE"
}

test_ignore_age_accepts_age_eligible_release() {
    new_fixture
    run_cli destination-path install --release v2.0.0 --ignore-age
    install_status=$STATUS
    run_cli destination-path verify --release v2.0.0 --ignore-age
    if [ "$install_status" -eq 0 ] && [ "$STATUS" -eq 0 ] \
        && [ "$(cat "$TEST_LOG/download-version")" = v2.0.0 ] \
        && grep -q 'explicitly requested immutable stable v2.0.0; release is age-eligible' "$FIXTURE/out"; then
        pass '--ignore-age accepts an already age-eligible release without claiming a waiver'
    else
        fail '--ignore-age accepts an already age-eligible release without claiming a waiver'
    fi
    rm -rf "$FIXTURE"
}

test_verify_ignore_age_requires_release() {
    new_fixture
    run_cli foundry-path verify --ignore-age
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/download-version" ] \
        && grep -Fq 'Error: verify requires --release' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'verify requires an explicit release when --ignore-age is used'
    else
        fail 'verify requires an explicit release when --ignore-age is used'
    fi
    rm -rf "$FIXTURE"
}

test_requested_release_must_be_immutable() {
    new_fixture
    TEST_INSTALLED_IMMUTABLE=false
    export TEST_INSTALLED_IMMUTABLE
    run_cli foundry-path verify --release v2.1.0 --ignore-age
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'requested Foundry release is not immutable: v2.1.0' "$FIXTURE/out"; then
        pass 'mutable release cannot bypass the cooling period'
    else
        fail 'mutable release cannot bypass the cooling period'
    fi
    rm -rf "$FIXTURE"
}

test_requested_release_metadata_must_be_valid() {
    ok=1

    new_fixture
    run_cli foundry-path install --release nightly
    [ "$STATUS" -ne 0 ] && ! grep -q 'releases/tags/nightly' "$TEST_LOG/gh" \
        && grep -q 'does not use a stable version tag' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    run_cli foundry-path install --release v2.2.0
    [ "$STATUS" -ne 0 ] && grep -q 'could not find requested Foundry release metadata' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_REQUESTED_DRAFT=true
    export TEST_REQUESTED_DRAFT
    run_cli foundry-path verify --release v2.1.0 --ignore-age
    [ "$STATUS" -ne 0 ] && grep -q 'requested Foundry release is not stable' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_REQUESTED_PRERELEASE=true
    export TEST_REQUESTED_PRERELEASE
    run_cli foundry-path verify --release v2.1.0 --ignore-age
    [ "$STATUS" -ne 0 ] && grep -q 'requested Foundry release is not stable' "$FIXTURE/out" || ok=0
    rm -rf "$FIXTURE"

    if [ "$ok" -eq 1 ]; then
        pass 'requested release metadata must identify an existing stable release'
    else
        fail 'requested release metadata must identify an existing stable release'
    fi
}

test_verify_requested_release_must_match_installed_release() {
    new_fixture
    run_cli foundry-path verify --release v2.1.0 --ignore-age
    if [ "$STATUS" -eq 1 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'installed Foundry release v2.0.0 does not match requested release v2.1.0' "$FIXTURE/out" \
        && grep -q '^Required action: install$' "$FIXTURE/out" \
        && grep -q '^Installation command: make install-foundry release=v2.1.0 ignore-age=1$' "$FIXTURE/out"; then
        pass 'installed release must match the requested young release'
    else
        fail 'installed release must match the requested young release'
    fi
    rm -rf "$FIXTURE"
}

test_make_ignore_age_requires_one() {
    ok=1

    output=$(make -s -n -C "$ROOT" verify-foundry release=v2.0.0 ignore-age=1 2>&1)
    status=$?
    [ "$status" -eq 0 ] && [[ "$output" = *' --release "v2.0.0" --ignore-age'* ]] || ok=0

    output=$(make -s -n -C "$ROOT" verify-foundry release=v2.0.0 ignore-age= 2>&1)
    status=$?
    [ "$status" -eq 0 ] && [[ "$output" != *' --ignore-age'* ]] || ok=0

    for ignore_age_value in 0 false yes; do
        output=$(make -s -n -C "$ROOT" verify-foundry release=v2.0.0 ignore-age="$ignore_age_value" 2>&1)
        status=$?
        [ "$status" -ne 0 ] && [[ "$output" = *'ignore-age must be 1'* ]] || ok=0
    done

    if [ "$ok" -eq 1 ]; then
        pass 'Make ignore-age accepts only 1'
    else
        fail 'Make ignore-age accepts only 1'
    fi
}

test_make_install_requires_release() {
    output=$(make -s -C "$ROOT" install-foundry 2>&1)
    status=$?
    if [ "$status" -ne 0 ] && [[ "$output" = *'Error: --release requires a value'* ]]; then
        pass 'Make install requires an explicit release'
    else
        fail 'Make install requires an explicit release'
    fi
}

test_make_verify_requires_release() {
    output=$(make -s -C "$ROOT" verify-foundry 2>&1)
    status=$?
    if [ "$status" -ne 0 ] && [[ "$output" = *'Error: --release requires a value'* ]]; then
        pass 'Make verify requires an explicit release'
    else
        fail 'Make verify requires an explicit release'
    fi
}

test_install_platform_matrix() {
    while IFS='|' read -r os arch rosetta target description; do
        new_fixture "$os" "$arch" "$rosetta"
        run_cli destination-path install --release v2.0.0
        if [ "$STATUS" -eq 0 ] \
            && grep -Fq -- "--pattern foundry_v2.0.0_${target}.tar.gz" "$TEST_LOG/gh"; then
            pass "$description"
        else
            fail "$description"
        fi
        rm -rf "$FIXTURE"
    done <<'EOF'
Linux|x86_64|0|linux_amd64|Linux x86_64 selects the amd64 asset
Linux|amd64|0|linux_amd64|Linux amd64 selects the amd64 asset
Linux|arm64|0|linux_arm64|Linux arm64 selects the arm64 asset
Linux|aarch64|0|linux_arm64|Linux aarch64 selects the arm64 asset
Darwin|x86_64|0|darwin_amd64|Darwin x86_64 selects the amd64 asset
Darwin|amd64|0|darwin_amd64|Darwin amd64 selects the amd64 asset
Darwin|arm64|0|darwin_arm64|Darwin arm64 selects the arm64 asset
Darwin|aarch64|0|darwin_arm64|Darwin aarch64 selects the arm64 asset
Darwin|x86_64|1|darwin_arm64|Rosetta selects the native arm64 asset
EOF
}

test_install_asset_failure_blocks_mutation() {
    new_fixture
    TEST_ATTEST_FAIL=foundry_v2.0.0_linux_amd64.tar.gz; export TEST_ATTEST_FAIL
    run_cli no-foundry install --release v2.0.0
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/tar" ] && [ ! -e "$TEST_LOG/install" ]; then
        pass 'release asset failure blocks extraction and installation'
    else
        fail 'release asset failure blocks extraction and installation'
    fi
    rm -rf "$FIXTURE"
}

test_install_missing_path_reports_action() {
    new_fixture
    run_cli no-foundry install --release v2.0.0
    if [ "$STATUS" -eq 0 ] && [ -x "$HOME/.foundry/bin/forge" ] \
        && grep -q '^Required action: update-path$' "$FIXTURE/out" \
        && grep -q 'export PATH=' "$FIXTURE/out"; then
        pass 'successful install outside PATH reports the required action'
    else
        fail 'successful install outside PATH reports the required action'
    fi
    rm -rf "$FIXTURE"
}

test_install_failure_rolls_back() {
    new_fixture
    printf 'old forge\n' > "$HOME/.foundry/bin/forge"
    printf 'old cast\n' > "$HOME/.foundry/bin/cast"
    chmod 0700 "$HOME/.foundry/bin/forge" "$HOME/.foundry/bin/cast"
    TEST_ATTEST_FAIL=cast
    TEST_BINARY_ATTEST_STATUS=42
    export TEST_ATTEST_FAIL TEST_BINARY_ATTEST_STATUS
    run_cli destination-path install --release v2.0.0
    if [ "$STATUS" -eq 1 ] \
        && [ "$(cat "$HOME/.foundry/bin/forge")" = 'old forge' ] \
        && [ "$(cat "$HOME/.foundry/bin/cast")" = 'old cast' ] \
        && [ ! -e "$HOME/.foundry/bin/anvil" ] \
        && [ ! -e "$HOME/.foundry/bin/chisel" ] \
        && grep -q 'Previous Foundry installation restored' "$FIXTURE/out"; then
        pass 'post-install failure restores the prior installation'
    else
        fail 'post-install failure restores the prior installation'
    fi
    rm -rf "$FIXTURE"
}

test_install_failure_removes_new_destination_parent() {
    new_fixture
    rm -rf "$HOME/.foundry"
    TEST_ATTEST_FAIL=cast
    TEST_BINARY_ATTEST_STATUS=42
    export TEST_ATTEST_FAIL TEST_BINARY_ATTEST_STATUS
    run_cli no-foundry install --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ ! -e "$HOME/.foundry" ] \
        && grep -q 'Previous Foundry installation restored' "$FIXTURE/out"; then
        pass 'post-install failure removes the destination parent created by the install'
    else
        fail 'post-install failure removes the destination parent created by the install'
    fi
    rm -rf "$FIXTURE"
}

test_install_failure_preserves_existing_destination_parent() {
    new_fixture
    rmdir "$HOME/.foundry/bin"
    TEST_ATTEST_FAIL=cast
    TEST_BINARY_ATTEST_STATUS=42
    export TEST_ATTEST_FAIL TEST_BINARY_ATTEST_STATUS
    run_cli no-foundry install --release v2.0.0
    if [ "$STATUS" -eq 1 ] && [ -d "$HOME/.foundry" ] && [ ! -e "$HOME/.foundry/bin" ] \
        && grep -q 'Previous Foundry installation restored' "$FIXTURE/out"; then
        pass 'post-install failure preserves a pre-existing destination parent'
    else
        fail 'post-install failure preserves a pre-existing destination parent'
    fi
    rm -rf "$FIXTURE"
}

test_invalid_command_fails() {
    new_fixture
    run_cli foundry-path invalid
    if [ "$STATUS" -ne 0 ] && grep -Fq 'Error: unknown command: invalid' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'invalid subcommand reports a specific error and the manual entry'
    else
        fail 'invalid subcommand reports a specific error and the manual entry'
    fi
    rm -rf "$FIXTURE"
}

test_help_succeeds_without_environment_checks() {
    ok=1

    for invocation in top-level select verify install; do
        new_fixture
        case "$invocation" in
            top-level)
                arguments=(--help)
                expected_usage=expected_top_level_usage
                ;;
            select)
                arguments=(select --help)
                expected_usage=expected_select_usage
                ;;
            verify)
                arguments=(verify --help)
                expected_usage=expected_verify_usage
                ;;
            install)
                arguments=(install --help)
                expected_usage=expected_install_usage
                ;;
        esac
        PATH="$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "${arguments[@]}" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
        status=$?
        [ "$status" -eq 0 ] || ok=0
        [ ! -s "$FIXTURE/stderr" ] || ok=0
        [ ! -e "$TEST_LOG/gh" ] || ok=0
        diff -u <("$expected_usage") "$FIXTURE/stdout" >/dev/null || ok=0
        rm -rf "$FIXTURE"
    done

    if [ "$ok" -eq 1 ]; then
        pass 'top-level and command help print their manual entries without environment checks'
    else
        fail 'top-level and command help print their manual entries without environment checks'
    fi
}

test_invalid_invocations_report_specific_errors() {
    ok=1

    while IFS='|' read -r expected expected_usage arguments; do
        new_fixture
        if [ -n "$arguments" ]; then
            read -r -a argv <<< "$arguments"
            PATH="$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "${argv[@]}" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
        else
            PATH="$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
        fi
        status=$?
        [ "$status" -eq 1 ] || ok=0
        [ ! -s "$FIXTURE/stdout" ] || ok=0
        {
            printf 'Error: %s\n\n' "$expected"
            "$expected_usage"
        } > "$FIXTURE/expected-stderr"
        diff -u "$FIXTURE/expected-stderr" "$FIXTURE/stderr" >/dev/null || ok=0
        [ ! -e "$TEST_LOG/gh" ] || ok=0
        rm -rf "$FIXTURE"
    done <<'EOF'
command is required|expected_top_level_usage|
unknown command: invalid|expected_top_level_usage|invalid
--help cannot be combined with other arguments|expected_top_level_usage|--help verify
unknown option: -r|expected_select_usage|select -r
select does not accept --release|expected_select_usage|select --release v2.0.0
select does not accept --release|expected_select_usage|select --release=v2.0.0
--help cannot be combined with other arguments|expected_select_usage|select --help --ignore-age
unknown option: -r|expected_verify_usage|verify -r v2.0.0
unexpected argument: extra|expected_verify_usage|verify extra
verify requires --release|expected_verify_usage|verify
--release requires a value|expected_verify_usage|verify --release
--release requires a value|expected_verify_usage|verify --release=
--release requires a value|expected_verify_usage|verify --release --ignore-age
verify requires --release|expected_verify_usage|verify --ignore-age
--help cannot be combined with other arguments|expected_verify_usage|verify --help --release v2.0.0
install requires --release|expected_install_usage|install
--release requires a value|expected_install_usage|install --release
--help cannot be combined with other arguments|expected_install_usage|install --help --release v2.0.0
EOF

    if [ "$ok" -eq 1 ]; then
        pass 'invalid invocations report specific errors and the manual entry'
    else
        fail 'invalid invocations report specific errors and the manual entry'
    fi
}

test_release_option_requires_value() {
    new_fixture
    run_cli foundry-path verify --release
    if [ "$STATUS" -ne 0 ] && grep -Fq 'Error: --release requires a value' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'release option without a value reports a specific error'
    else
        fail 'release option without a value reports a specific error'
    fi
    rm -rf "$FIXTURE"
}

test_release_option_rejects_empty_equals_value() {
    new_fixture
    run_cli foundry-path verify --release=
    if [ "$STATUS" -ne 0 ] && grep -Fq 'Error: --release requires a value' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'release option rejects an empty equals value'
    else
        fail 'release option rejects an empty equals value'
    fi
    rm -rf "$FIXTURE"
}

test_short_options_are_rejected() {
    new_fixture
    run_cli foundry-path verify -r v2.0.0
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -Fq 'Error: unknown option: -r' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'short options are rejected'
    else
        fail 'short options are rejected'
    fi
    rm -rf "$FIXTURE"
}


test_missing_command_fails() {
    new_fixture
    PATH="$FIXTURE/foundry-bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" > "$FIXTURE/out" 2>&1
    STATUS=$?
    if [ "$STATUS" -ne 0 ] && grep -Fq 'Error: command is required' "$FIXTURE/out" \
        && grep -Fq 'SYNOPSIS' "$FIXTURE/out"; then
        pass 'missing subcommand reports a specific error and the manual entry'
    else
        fail 'missing subcommand reports a specific error and the manual entry'
    fi
    rm -rf "$FIXTURE"
}

test_select_is_metadata_only
test_select_ignore_age_chooses_newest_stable_release
test_verify_requires_release
test_select_rejects_release
test_make_select_forwards_ignore_age
test_verify_eligible
test_attestation_subject_must_match_verified_path
test_modified_cli_is_rejected_before_reporting_source_metadata
test_shasum_fallback_forces_portable_locale
test_verify_rejects_mutable_release
test_verify_older_fails
test_verify_newer_fails
test_verify_accepts_requested_young_release
test_young_release_requires_ignore_age
test_ignore_age_accepts_age_eligible_release
test_verify_ignore_age_requires_release
test_requested_release_must_be_immutable
test_requested_release_metadata_must_be_valid
test_verify_requested_release_must_match_installed_release
test_verify_rejects_missing_mixed_and_unattested
test_verify_remote_failures_stop_without_installation
test_make_ignore_age_requires_one
test_make_install_requires_release
test_make_verify_requires_release
test_verify_replaces_nonrequired_prerelease
test_verify_replaces_nonrequired_rc
test_verify_reports_version_failure
test_install_requires_release
test_install_skips_verified_matching_destination
test_select_without_eligible_release_fails
test_install_accepts_explicit_age_eligible_release
test_install_accepts_requested_young_release
test_install_platform_matrix
test_install_asset_failure_blocks_mutation
test_install_missing_path_reports_action
test_install_failure_rolls_back
test_install_failure_removes_new_destination_parent
test_install_failure_preserves_existing_destination_parent
test_invalid_command_fails
test_help_succeeds_without_environment_checks
test_invalid_invocations_report_specific_errors
test_release_option_requires_value
test_release_option_rejects_empty_equals_value
test_short_options_are_rejected
test_missing_command_fails

printf '%s passed; %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
