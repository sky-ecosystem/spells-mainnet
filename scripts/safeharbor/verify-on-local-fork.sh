#!/usr/bin/env bash

# Deploy, schedule, and cast the current DssSpell on a local Mainnet fork, then verify
# that resulting SafeHarbor state matches the configured Sheet.
set -euo pipefail

FORK_BLOCK_NUMBER="${1:-}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
LOCAL_RPC_URL="http://127.0.0.1:${ANVIL_PORT}"
CHAINLOG="0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F"
CHIEF_HAT_SLOT="0x0000000000000000000000000000000000000000000000000000000000000001"
ANVIL_SENDER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
TMP_DIR="$(mktemp -d)"
ANVIL_LOG="${TMP_DIR}/anvil.log"
ANVIL_IPC="${TMP_DIR}/anvil.ipc"
ANVIL_PID=""

print_anvil_log() {
    # Keep successful runs quiet, but replay captured Anvil output when startup fails.
    if [[ -s "$ANVIL_LOG" ]]; then
        while IFS= read -r line; do
            printf '%s\n' "$line" >&2
        done <"$ANVIL_LOG"
    fi
}

is_tcp_port_open() {
    # Bash treats /dev/tcp/host/port as a TCP connection. The no-op `:` closes it immediately.
    (: <>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if [[ -n "$ANVIL_PID" ]] && kill -0 "$ANVIL_PID" 2>/dev/null; then
        kill "$ANVIL_PID" 2>/dev/null || true
        for _ in {1..20}; do
            if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
                break
            fi
            sleep 0.1
        done
        if kill -0 "$ANVIL_PID" 2>/dev/null; then
            kill -KILL "$ANVIL_PID" 2>/dev/null || true
        fi
        wait "$ANVIL_PID" 2>/dev/null || true
    fi

    rm -rf "$TMP_DIR"
    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The > 5 length check prevents arithmetic overflow; 10# forces decimal parsing for values such as 08080.
if [[ ! "$ANVIL_PORT" =~ ^[0-9]+$ ]] || ((${#ANVIL_PORT} > 5)) || ((10#$ANVIL_PORT < 1 || 10#$ANVIL_PORT > 65535)); then
    echo "ANVIL_PORT must be between 1 and 65535" >&2
    exit 1
fi

if [[ -n "$FORK_BLOCK_NUMBER" ]] && [[ ! "$FORK_BLOCK_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Fork block must be a positive integer" >&2
    exit 1
fi

for command in anvil cast forge git jq npm; do
    command -v "$command" >/dev/null || {
        echo "Missing required executable: $command" >&2
        exit 1
    }
done

if [[ -z "${ETH_RPC_URL:-}" ]]; then
    echo "Please set ETH_RPC_URL to a Mainnet RPC URL" >&2
    exit 1
fi

if [[ "$(cast chain-id --rpc-url "$ETH_RPC_URL")" != "1" ]]; then
    echo "ETH_RPC_URL must point to Ethereum Mainnet" >&2
    exit 1
fi

commit_sha="$(git rev-parse HEAD)"

if is_tcp_port_open "$ANVIL_PORT"; then
    echo "Port $ANVIL_PORT is already in use" >&2
    exit 1
fi

anvil_args=(
    --fork-url "$ETH_RPC_URL"
    --chain-id 1
    --hardfork cancun
    --host 127.0.0.1
    --port "$ANVIL_PORT"
    --ipc "$ANVIL_IPC"
    --gas-limit 1000000000
)

if [[ -n "$FORK_BLOCK_NUMBER" ]]; then
    anvil_args+=(--fork-block-number "$FORK_BLOCK_NUMBER")
fi

echo "Starting Anvil fork at ${LOCAL_RPC_URL}"
anvil "${anvil_args[@]}" >"$ANVIL_LOG" 2>&1 &
ANVIL_PID=$!

anvil_ready=false
for _ in {1..60}; do
    if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
        echo "Anvil exited before becoming ready" >&2
        print_anvil_log
        exit 1
    fi

    # The unique IPC socket proves readiness belongs to the Anvil child launched above.
    if [[ -S "$ANVIL_IPC" ]]; then
        if chain_id="$(cast chain-id --rpc-url "$ANVIL_IPC" 2>/dev/null)"; then
            if [[ "$chain_id" != "1" ]]; then
                echo "Anvil fork did not start with chain ID 1" >&2
                print_anvil_log
                exit 1
            fi
            if [[ "$(cast chain-id --rpc-url "$LOCAL_RPC_URL" 2>/dev/null)" != "1" ]]; then
                sleep 0.5
                continue
            fi
            if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
                echo "Anvil exited before becoming ready" >&2
                print_anvil_log
                exit 1
            fi
            anvil_ready=true
            break
        fi
    fi

    sleep 0.5
done

if [[ "$anvil_ready" != "true" ]]; then
    echo "Anvil did not become ready within 30 seconds" >&2
    print_anvil_log
    exit 1
fi

fork_block_number="$(cast block-number --rpc-url "$LOCAL_RPC_URL")"
echo "Fork block: $fork_block_number"
echo "Commit: $commit_sha"

echo "Deploying local DssSpell"
deploy_output="$(
    forge create \
        --no-cache \
        --broadcast \
        --json \
        --unlocked \
        --from "$ANVIL_SENDER" \
        --rpc-url "$LOCAL_RPC_URL" \
        src/DssSpell.sol:DssSpell
)"
spell_address="$(jq -r '.deployedTo // empty' <<<"$deploy_output")"

if [[ ! "$spell_address" =~ ^0x[[:xdigit:]]{40}$ ]]; then
    echo "Could not read deployed spell address" >&2
    exit 1
fi

chief_address="$(
    cast call \
        --rpc-url "$LOCAL_RPC_URL" \
        "$CHAINLOG" \
        "getAddress(bytes32)(address)" \
        "$(cast format-bytes32-string MCD_ADM)"
)"
spell_hat_word="$(cast abi-encode 'f(address)' "$spell_address")"

echo "Giving local spell the Chief hat"
cast rpc \
    --rpc-url "$LOCAL_RPC_URL" \
    anvil_setStorageAt \
    "$chief_address" \
    "$CHIEF_HAT_SLOT" \
    "$spell_hat_word" >/dev/null

hat_address="$(cast call --rpc-url "$LOCAL_RPC_URL" "$chief_address" "hat()(address)")"
# Use tr instead of Bash 4 lowercase expansion for compatibility with macOS Bash 3.2.
normalized_hat_address="$(printf '%s' "$hat_address" | tr '[:upper:]' '[:lower:]')"
normalized_spell_address="$(printf '%s' "$spell_address" | tr '[:upper:]' '[:lower:]')"
if [[ "$normalized_hat_address" != "$normalized_spell_address" ]]; then
    echo "Local spell did not receive the Chief hat" >&2
    exit 1
fi

echo "Scheduling local spell"
cast send \
    --rpc-url "$LOCAL_RPC_URL" \
    --unlocked \
    --from "$ANVIL_SENDER" \
    --gas-limit 100000000 \
    "$spell_address" \
    "schedule()" >/dev/null

next_cast_time_raw="$(
    cast call \
        --rpc-url "$LOCAL_RPC_URL" \
        --data "$(cast calldata 'nextCastTime()')" \
        "$spell_address"
)"
next_cast_time="$(cast to-dec "$next_cast_time_raw")"

echo "Warping to ${next_cast_time} and casting local spell"
cast rpc \
    --rpc-url "$LOCAL_RPC_URL" \
    evm_setNextBlockTimestamp \
    "$(cast to-hex "$next_cast_time")" >/dev/null
cast send \
    --rpc-url "$LOCAL_RPC_URL" \
    --unlocked \
    --from "$ANVIL_SENDER" \
    --gas-limit 900000000 \
    "$spell_address" \
    "cast()" >/dev/null

if [[ "$(cast call --rpc-url "$LOCAL_RPC_URL" "$spell_address" "done()(bool)")" != "true" ]]; then
    echo "Local spell cast did not complete" >&2
    exit 1
fi

echo "Checking SafeHarbor state"
safeharbor_status=0
ETH_RPC_URL="$LOCAL_RPC_URL" \
    npm --prefix scripts/safeharbor run --silent verify || safeharbor_status=$?

if ((safeharbor_status != 0)); then
    exit "$safeharbor_status"
fi

echo "SafeHarbor Anvil preflight passed"
