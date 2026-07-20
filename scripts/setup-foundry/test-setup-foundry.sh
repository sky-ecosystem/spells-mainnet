#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CLI="$ROOT/scripts/setup-foundry/setup-foundry.sh"
BASH_PATH=$(command -v bash)
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

apply_stub() {
    name=$1
    body=$2
    printf '%s\n' "$body" > "$FIXTURE/bin/$name"
    chmod +x "$FIXTURE/bin/$name"
}

new_fixture() {
    FIXTURE=$(mktemp -d)
    export FIXTURE
    export HOME="$FIXTURE/home"
    export TEST_LOG="$FIXTURE/log"
    export TEST_OS=Linux
    export TEST_ARCH=x86_64
    export TEST_ROSETTA=0
    export TEST_NO_PREVIOUS=0
    export TEST_INSTALLED_TAG=v2.0.0
    export TEST_INSTALLED_IMMUTABLE=true
    export TEST_MIXED_BINARY=
    export TEST_ATTEST_FAIL=
    export TEST_BINARY_ATTEST_STATUS=1
    export TEST_VERSION_FAIL=
    mkdir -p "$HOME/.foundry/bin" "$FIXTURE/bin" "$FIXTURE/foundry-bin" "$TEST_LOG"

    apply_stub gh '#!/usr/bin/env bash
set -eu
printf "%s\n" "$*" >> "$TEST_LOG/gh"
if [ "$1 $2" = "auth status" ]; then exit 0; fi
if [ "$1" = api ] && [ "${2:-}" = "--paginate" ]; then
    if [ "${TEST_NO_PREVIOUS:-0}" != 1 ]; then
        printf "v2.0.0\t2026-06-01T00:00:00Z\thttps://example.test/v2.0.0\n"
    fi
    exit 0
fi
case "${2:-}" in
    repos/foundry-rs/foundry/releases/tags/*)
        tag=${2##*/}
        case "$tag" in
            v2.1.0) printf "v2.1.0\t2026-07-12T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
            v2.0.0) printf "v2.0.0\t2026-06-01T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
            v1.9.0) printf "v1.9.0\t2026-05-01T00:00:00Z\tfalse\tfalse\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
            v1.8.0-rc1) printf "v1.8.0-rc1\t2026-04-01T00:00:00Z\tfalse\ttrue\t%s\n" "$TEST_INSTALLED_IMMUTABLE" ;;
            *) exit 1 ;;
        esac
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
    printf "[{\"verificationResult\":{\"statement\":{\"subject\":[{\"name\":\"%s\"}]},\"signature\":{\"certificate\":{\"buildSignerURI\":\"https://github.com/foundry-rs/foundry/.github/workflows/release.yml@refs/tags/%s\",\"sourceRepositoryURI\":\"https://github.com/foundry-rs/foundry\"}}}}]\n" "$name" "$tag"
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
    printf "%s\n" "$FIXTURE/repository"
elif [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse HEAD" ]; then
    printf "0123456789abcdef0123456789abcdef01234567\n"
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
    if [ "$path_mode" = foundry-path ]; then
        PATH="$FIXTURE/foundry-bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" > "$FIXTURE/out" 2>&1
    elif [ "$path_mode" = destination-path ]; then
        PATH="$HOME/.foundry/bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" > "$FIXTURE/out" 2>&1
    else
        PATH="$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" "$command" > "$FIXTURE/out" 2>&1
    fi
    STATUS=$?
}

test_verify_eligible() {
    new_fixture
    run_cli
    attestations=$(grep -c '^attestation verify ' "$TEST_LOG/gh" 2>/dev/null || true)
    if [ -e "$TEST_LOG/versions" ]; then versions=$(wc -l < "$TEST_LOG/versions"); else versions=0; fi
    if [ "$STATUS" -eq 0 ] && [ "$attestations" -eq 4 ] && [ "$versions" -eq 4 ] \
        && grep -q 'api --paginate.*now -' "$TEST_LOG/gh" \
        && grep -q '\.immutable == true' "$TEST_LOG/gh" \
        && grep -q 'Selection policy: newest immutable stable release published at least seven days ago' "$FIXTURE/out" \
        && grep -q 'Foundry verification completed successfully' "$FIXTURE/out"; then
        pass 'newest age-eligible immutable PATH toolchain is verified'
    else
        fail 'newest age-eligible immutable PATH toolchain is verified'
    fi
    rm -rf "$FIXTURE"
}

test_verify_rejects_mutable_release() {
    new_fixture
    TEST_INSTALLED_IMMUTABLE=false
    export TEST_INSTALLED_IMMUTABLE
    run_cli
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'is not immutable' "$FIXTURE/out"; then
        pass 'mutable installed release fails verification before execution'
    else
        fail 'mutable installed release fails verification before execution'
    fi
    rm -rf "$FIXTURE"
}

test_verify_rejects_prerelease() {
    new_fixture
    TEST_INSTALLED_TAG=v1.8.0-rc1; export TEST_INSTALLED_TAG
    run_cli
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] && grep -q 'is not stable' "$FIXTURE/out"; then
        pass 'prerelease toolchain fails verification before execution'
    else
        fail 'prerelease toolchain fails verification before execution'
    fi
    rm -rf "$FIXTURE"
}

test_verify_reports_version_failure() {
    new_fixture
    TEST_VERSION_FAIL=cast; export TEST_VERSION_FAIL
    run_cli
    if [ "$STATUS" -ne 0 ] && grep -q 'could not read version from' "$FIXTURE/out"; then
        pass 'binary version failure has a useful diagnostic'
    else
        fail 'binary version failure has a useful diagnostic'
    fi
    rm -rf "$FIXTURE"
}

test_missing_jq_fails_explicitly() {
    new_fixture
    mkdir "$FIXTURE/minimal-bin"
    ln -s "$FIXTURE/bin/gh" "$FIXTURE/minimal-bin/gh"
    ln -s "$FIXTURE/bin/git" "$FIXTURE/minimal-bin/git"
    PATH="$FIXTURE/minimal-bin" "$BASH_PATH" "$CLI" verify > "$FIXTURE/out" 2>&1
    STATUS=$?
    if [ "$STATUS" -ne 0 ] && grep -q 'required command not found: jq' "$FIXTURE/out"; then
        pass 'missing jq fails with an explicit prerequisite error'
    else
        fail 'missing jq fails with an explicit prerequisite error'
    fi
    rm -rf "$FIXTURE"
}

test_verify_older_fails() {
    new_fixture
    TEST_INSTALLED_TAG=v1.9.0; export TEST_INSTALLED_TAG
    run_cli
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] \
        && grep -q 'does not match newest eligible immutable stable v2.0.0' "$FIXTURE/out"; then
        pass 'older verified stable release fails the version policy'
    else
        fail 'older verified stable release fails the version policy'
    fi
    rm -rf "$FIXTURE"
}

test_verify_too_new_fails() {
    new_fixture
    TEST_INSTALLED_TAG=v2.1.0
    export TEST_INSTALLED_TAG
    run_cli
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] && grep -q 'seven-day' "$FIXTURE/out"; then
        pass 'too-new stable release fails the seven-day policy'
    else
        fail 'too-new stable release fails the seven-day policy'
    fi
    rm -rf "$FIXTURE"
}

test_verify_rejects_missing_mixed_and_unattested() {
    ok=1

    new_fixture
    rm "$FIXTURE/foundry-bin/chisel"
    run_cli
    [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_MIXED_BINARY=cast; export TEST_MIXED_BINARY
    run_cli
    [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] || ok=0
    rm -rf "$FIXTURE"

    new_fixture
    TEST_ATTEST_FAIL=cast; export TEST_ATTEST_FAIL
    run_cli
    [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/versions" ] || ok=0
    rm -rf "$FIXTURE"

    if [ "$ok" -eq 1 ]; then
        pass 'missing, mixed, and unattested toolchains fail before execution'
    else
        fail 'missing, mixed, and unattested toolchains fail before execution'
    fi
}

test_install_selects_newest_age_eligible() {
    new_fixture
    run_cli destination-path install
    if [ "$STATUS" -eq 0 ] && [ "$(cat "$TEST_LOG/download-version")" = v2.0.0 ] \
        && [ -x "$HOME/.foundry/bin/forge" ]; then
        pass 'install selects the newest age-eligible immutable stable release'
    else
        fail 'install selects the newest age-eligible immutable stable release'
    fi
    rm -rf "$FIXTURE"
}

test_install_selects_arm64_under_rosetta() {
    new_fixture
    TEST_OS=Darwin
    TEST_ARCH=x86_64
    TEST_ROSETTA=1
    export TEST_OS TEST_ARCH TEST_ROSETTA
    run_cli destination-path install
    if [ "$STATUS" -eq 0 ] \
        && grep -q -- '--pattern foundry_v2.0.0_darwin_arm64.tar.gz' "$TEST_LOG/gh"; then
        pass 'install selects the native arm64 asset under Rosetta'
    else
        fail 'install selects the native arm64 asset under Rosetta'
    fi
    rm -rf "$FIXTURE"
}

test_install_selects_amd64_on_intel_macos() {
    new_fixture
    TEST_OS=Darwin
    TEST_ARCH=x86_64
    export TEST_OS TEST_ARCH
    run_cli destination-path install
    if [ "$STATUS" -eq 0 ] \
        && grep -q -- '--pattern foundry_v2.0.0_darwin_amd64.tar.gz' "$TEST_LOG/gh"; then
        pass 'install keeps the amd64 asset on Intel macOS'
    else
        fail 'install keeps the amd64 asset on Intel macOS'
    fi
    rm -rf "$FIXTURE"
}

test_install_without_eligible_immutable_release_fails() {
    new_fixture
    TEST_NO_PREVIOUS=1
    export TEST_NO_PREVIOUS
    run_cli no-foundry install
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/download-version" ] \
        && grep -q 'no immutable stable Foundry release published at least seven days ago was found' "$FIXTURE/out"; then
        pass 'install fails when no eligible immutable stable release exists'
    else
        fail 'install fails when no eligible immutable stable release exists'
    fi
    rm -rf "$FIXTURE"
}

test_install_asset_failure_blocks_mutation() {
    new_fixture
    TEST_ATTEST_FAIL=foundry_v2.0.0_linux_amd64.tar.gz; export TEST_ATTEST_FAIL
    run_cli no-foundry install
    if [ "$STATUS" -ne 0 ] && [ ! -e "$TEST_LOG/tar" ] && [ ! -e "$TEST_LOG/install" ]; then
        pass 'release asset failure blocks extraction and installation'
    else
        fail 'release asset failure blocks extraction and installation'
    fi
    rm -rf "$FIXTURE"
}

test_install_missing_path_exits_two() {
    new_fixture
    run_cli no-foundry install
    if [ "$STATUS" -eq 2 ] && [ -x "$HOME/.foundry/bin/forge" ] && grep -q 'export PATH=' "$FIXTURE/out"; then
        pass 'successful install outside PATH exits 2'
    else
        fail 'successful install outside PATH exits 2'
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
    run_cli destination-path install
    if [ "$STATUS" -eq 42 ] \
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

test_invalid_command_fails() {
    new_fixture
    run_cli foundry-path invalid
    if [ "$STATUS" -ne 0 ] && grep -q 'Usage:' "$FIXTURE/out"; then
        pass 'invalid subcommand fails with usage'
    else
        fail 'invalid subcommand fails with usage'
    fi
    rm -rf "$FIXTURE"
}


test_missing_command_fails() {
    new_fixture
    PATH="$FIXTURE/foundry-bin:$FIXTURE/bin:/usr/bin:/bin" "$BASH_PATH" "$CLI" > "$FIXTURE/out" 2>&1
    STATUS=$?
    if [ "$STATUS" -ne 0 ] && grep -q 'Usage:' "$FIXTURE/out"; then
        pass 'missing subcommand fails with usage'
    else
        fail 'missing subcommand fails with usage'
    fi
    rm -rf "$FIXTURE"
}

test_verify_eligible
test_verify_rejects_mutable_release
test_verify_older_fails
test_verify_too_new_fails
test_verify_rejects_missing_mixed_and_unattested
test_verify_rejects_prerelease
test_verify_reports_version_failure
test_missing_jq_fails_explicitly
test_install_selects_newest_age_eligible
test_install_selects_arm64_under_rosetta
test_install_selects_amd64_on_intel_macos
test_install_without_eligible_immutable_release_fails
test_install_asset_failure_blocks_mutation
test_install_missing_path_exits_two
test_install_failure_rolls_back
test_invalid_command_fails
test_missing_command_fails

printf '%s passed; %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
