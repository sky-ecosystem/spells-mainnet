#!/usr/bin/env bash
set -euo pipefail

TEST_FILE="$(cd "$(dirname "$BASH_SOURCE")" && pwd)/$(basename "$BASH_SOURCE")"
PREFLIGHT="$(dirname "$TEST_FILE")/../verify-on-local-fork.sh"

assert_equal() {
    if [[ "$1" != "$2" ]]; then
        printf 'Expected: %s\nActual: %s\n' "$2" "$1" >&2
        exit 1
    fi
}

assert_contains() {
    if [[ "$1" != *"$2"* ]]; then
        printf 'Expected output to contain: %s\nActual: %s\n' "$2" "$1" >&2
        exit 1
    fi
}

git_at() {
    local repo="$1"
    shift
    git -c core.fsmonitor=false -C "$repo" "$@"
}

write_file() {
    local target="$1/$2"
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$3" > "$target"
}

commit() {
    git_at "$1" add .
    git_at "$1" -c user.name="SafeHarbor Fixture" -c user.email=fixture@example.invalid commit -qm fixture
}

init_repo() {
    mkdir -p "$1"
    git_at "$1" init -q
    write_file "$1" .gitignore $'.env\n/out/\n/cache/\nnode_modules/'
    write_file "$1" src/DssSpell.sol "// fixture spell"
    write_file "$1" foundry.toml $'[profile.default]\nsrc = \'src\''
    commit "$1"
}

setup_fixture() {
    local variable tool response
    while IFS= read -r variable; do
        unset "$variable"
    done < <(compgen -A variable GIT_)
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0 GIT_TERMINAL_PROMPT=0
    export BASH_ENV=/dev/null ENV=/dev/null

    fixture="$(mktemp -d /tmp/safeharbor-preflight-XXXXXX)"
    trap 'rm -rf -- "$fixture"' EXIT
    checkout="$fixture/checkout"
    call_log="$fixture/tool-calls"
    mkdir "$fixture/bin"
    : > "$call_log"
    export PATH="$fixture/bin:$PATH"
    export ETH_RPC_URL=https://rpc.example.invalid ANVIL_PORT=8545 SAFEHARBOR_CALL_LOG="$call_log"
    for tool in anvil cast forge jq npm; do
        response="exit 99"
        if [[ "$tool" == cast ]]; then
            response="printf '%s\n' 999"
        fi
        printf '%s\n' '#!/usr/bin/env bash' \
            "printf '%s\n' '$tool' >> \"\$SAFEHARBOR_CALL_LOG\"" \
            "$response" > "$fixture/bin/$tool"
        chmod +x "$fixture/bin/$tool"
    done
    init_repo "$checkout"
}

add_submodule() {
    local depth="$1" source="$fixture/library-source"
    init_repo "$source"
    if [[ "$depth" == nested ]]; then
        init_repo "$fixture/nested-source"
        git_at "$source" -c protocol.file.allow=always submodule add -q "$fixture/nested-source" lib/nested
        commit "$source"
    fi
    git_at "$checkout" -c protocol.file.allow=always submodule add -q "$source" lib/library
    commit "$checkout"
    git_at "$checkout" -c protocol.file.allow=always submodule update --init --recursive -q
    library="$checkout/lib/library"
}

run_preflight() {
    result_status=0
    (cd "$1" && "$BASH" "$PREFLIGHT") > "$fixture/stdout" 2> "$fixture/stderr" || result_status=$?
}

expect_rejected() {
    local cwd="$checkout"
    if [[ $# -gt 1 ]]; then
        cwd="$2"
    fi
    run_preflight "$cwd"
    assert_equal "$result_status" 1
    assert_contains "$(< "$fixture/stderr")" "$1"
    if [[ -s "$call_log" ]]; then
        printf 'Unexpected tool calls:\n%s\n' "$(< "$call_log")" >&2
        exit 1
    fi
    if [[ "$(< "$fixture/stdout")" == *"Commit:"* ]]; then
        printf 'Rejected checkout was reported as a verified commit\n' >&2
        exit 1
    fi
}

expect_guard_passed() {
    run_preflight "$checkout"
    # A different chain ID stops clean checkouts after the first RPC call, before Anvil.
    assert_equal "$result_status" 1
    assert_contains "$(< "$fixture/stderr")" "ETH_RPC_URL must point to Ethereum Mainnet"
    printf 'cast\n' > "$fixture/expected-calls"
    if ! cmp -s "$call_log" "$fixture/expected-calls"; then
        printf 'Expected only one cast call; actual:\n%s\n' "$(< "$call_log")" >&2
        exit 1
    fi
}

test_root_edit() {
    local before
    case "$1" in
        "unstaged source edits") write_file "$checkout" src/DssSpell.sol "// changed" ;;
        "staged source edits")
            write_file "$checkout" src/DssSpell.sol "// changed"
            git_at "$checkout" add src/DssSpell.sol
            ;;
        "Foundry configuration edits") write_file "$checkout" foundry.toml $'[profile.default]\noptimizer = true' ;;
        "tracked deletions") rm "$checkout/src/DssSpell.sol" ;;
        "untracked source files") write_file "$checkout" src/Extra.sol "// extra" ;;
        "unrelated tracked edits") write_file "$checkout" .gitignore ".env" ;;
        "unrelated untracked files") write_file "$checkout" notes.txt "local notes" ;;
    esac
    before="$(git_at "$checkout" status --porcelain=v1 --untracked-files=all --ignore-submodules=none)"
    expect_rejected "requires a clean checkout"
    assert_contains "$(< "$fixture/stderr")" "$checkout"
    assert_contains "$(< "$fixture/stderr")" "Commit or stash"
    assert_equal "$(git_at "$checkout" status --porcelain=v1 --untracked-files=all --ignore-submodules=none)" "$before"
}

test_submodule() {
    local depth="$1" scenario="$2" target parent
    add_submodule "$depth"
    target="$library"
    parent="$checkout"
    if [[ "$depth" == nested ]]; then
        target="$library/lib/nested"
        parent="$library"
    fi
    case "$scenario" in
        edit|"ignored dirty content")
            write_file "$target" src/DssSpell.sol "// changed dependency"
            if [[ "$scenario" == "ignored dirty content" ]]; then
                git_at "$checkout" config submodule.lib/library.ignore all
                if [[ "$depth" == nested ]]; then
                    git_at "$library" config submodule.lib/nested.ignore all
                fi
            fi
            ;;
        untracked) write_file "$target" src/Extra.sol "// extra dependency" ;;
        "wrong revision")
            write_file "$target" src/DssSpell.sol "// new revision"
            commit "$target"
            ;;
        uninitialized) git_at "$parent" submodule deinit --force --all ;;
    esac
    if [[ "$scenario" == uninitialized ]]; then
        expect_rejected "Submodules must be initialized"
    else
        expect_rejected "requires a clean checkout"
    fi
    if [[ "$depth" == direct ]]; then
        assert_contains "$(< "$fixture/stderr")" "lib/library"
    fi
}

test_index_flag() {
    local depth="$1" flag="$2" target="$checkout" before
    if [[ "$depth" == nested ]]; then
        add_submodule nested
        target="$library/lib/nested"
    fi
    git_at "$target" update-index "--$flag" src/DssSpell.sol
    if [[ "$flag" == assume-unchanged ]]; then
        write_file "$target" src/DssSpell.sol "// hidden edit"
    else
        rm "$target/src/DssSpell.sol"
    fi
    assert_equal "$(git_at "$checkout" status --porcelain=v1 --ignore-submodules=none)" ""
    before="$(git_at "$target" ls-files -v)"
    expect_rejected "assume-unchanged or skip-worktree"
    assert_equal "$(git_at "$target" ls-files -v)" "$before"
}

test_clean_checkout() {
    local repo
    case "$1" in
        checkout) ;;
        "detached HEAD") git_at "$checkout" checkout --detach -q ;;
        "recursive submodules") add_submodule nested ;;
        "ignored files")
            add_submodule nested
            for repo in "$checkout" "$library" "$library/lib/nested"; do
                write_file "$repo" .env "ETH_RPC_URL=https://rpc.example.invalid"
                write_file "$repo" out/fixture.json "{}"
                write_file "$repo" cache/fixture.json "{}"
                write_file "$repo" node_modules/fixture/index.js "// installed dependency"
            done
            ;;
    esac
    expect_guard_passed
}

test_git_failure() {
    local depth="$1" inspection="$2" message="$3" target="$checkout"
    if [[ "$depth" == nested ]]; then
        add_submodule nested
        target="$library/lib/nested"
    fi
    export SAFEHARBOR_REAL_GIT="$(command -v git)"
    export SAFEHARBOR_FAIL_REPO="$target" SAFEHARBOR_FAIL_INSPECTION="$inspection"
    # Git changes PATH in submodules; Bash startup injection reaches nested checks too.
    write_file "$fixture" git-failure.sh 'git() {
    if [[ "$PWD" == "$SAFEHARBOR_FAIL_REPO" ]]; then
        case " $* " in
            *" $SAFEHARBOR_FAIL_INSPECTION "*) echo "Fixture Git failure" >&2; exit 73 ;;
        esac
    fi
    command "$SAFEHARBOR_REAL_GIT" "$@"
}'
    export BASH_ENV="$fixture/git-failure.sh"
    expect_rejected "$message"
    assert_contains "$(< "$fixture/stderr")" "Fixture Git failure"
}

if [[ $# -gt 0 ]]; then
    if [[ "$1" != --case ]]; then
        printf 'Run this harness without arguments\n' >&2
        exit 1
    fi
    shift
    setup_fixture
    case "$1" in
        root_edit) test_root_edit "$2" ;;
        submodule) test_submodule "$2" "$3" ;;
        index_flag) test_index_flag "$2" "$3" ;;
        clean) test_clean_checkout "$2" ;;
        outside_git) expect_rejected "Cannot determine Git repository" "$fixture" ;;
        no_head)
            mkdir "$fixture/empty"
            git_at "$fixture/empty" init -q
            expect_rejected "Cannot determine Git HEAD" "$fixture/empty"
            ;;
        git_failure) test_git_failure "$2" "$3" "$4" ;;
        *) printf 'Unknown test case: %s\n' "$1" >&2; exit 1 ;;
    esac
    exit 0
fi

PASS=0
FAIL=0
logs="$(mktemp -d /tmp/safeharbor-preflight-tests-XXXXXX)"
trap 'rm -rf -- "$logs"' EXIT

run_test() {
    local name="$1"
    shift
    # A separate Bash process preserves errexit inside each case and isolates fixtures.
    if BASH_ENV=/dev/null ENV=/dev/null "$BASH" "$TEST_FILE" --case "$@" > "$logs/case.log" 2>&1; then
        PASS=$((PASS + 1))
        printf 'ok - %s\n' "$name"
    else
        FAIL=$((FAIL + 1))
        printf 'not ok - %s\n%s\n' "$name" "$(< "$logs/case.log")"
    fi
}

for scenario in "unstaged source edits" "staged source edits" "Foundry configuration edits" \
    "tracked deletions" "untracked source files" "unrelated tracked edits" "unrelated untracked files"; do
    run_test "rejects $scenario before contacting RPC" root_edit "$scenario"
done
for depth in direct nested; do
    for scenario in edit untracked "wrong revision" uninitialized "ignored dirty content"; do
        run_test "rejects $depth submodule $scenario before contacting RPC" submodule "$depth" "$scenario"
    done
done
for depth in root nested; do
    for flag in assume-unchanged skip-worktree; do
        run_test "rejects $depth $flag flags that hide tracked changes" index_flag "$depth" "$flag"
    done
done
for scenario in checkout "detached HEAD" "recursive submodules" "ignored files"; do
    run_test "allows clean $scenario" clean "$scenario"
done
run_test "rejects invocation outside a Git repository" outside_git
run_test "rejects a Git repository without a HEAD commit" no_head
run_test "fails closed when inspecting root index fails" git_failure root "ls-files -v" "Cannot inspect Git index"
run_test "fails closed when inspecting root status fails" git_failure root "status --porcelain=v1" "Cannot inspect Git worktree"
run_test "fails closed when inspecting submodule revisions fails" git_failure root "submodule status --recursive" "Cannot inspect recursive Git submodules"
run_test "fails closed when inspecting nested index fails" git_failure nested "ls-files -v" "Cannot inspect Git index"
run_test "fails closed when inspecting nested status fails" git_failure nested "status --porcelain=v1" "Cannot inspect Git worktree"

printf '\n%s passed; %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
