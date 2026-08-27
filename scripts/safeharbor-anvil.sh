#!/usr/bin/env bash
set -euo pipefail

FORK_BLOCK_NUMBER="${1:-}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
LOCAL_RPC_URL="http://127.0.0.1:${ANVIL_PORT}"
CHAINLOG="0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F"
CHIEF_HAT_SLOT="0x0000000000000000000000000000000000000000000000000000000000000001"
ANVIL_SENDER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
TMP_DIR="$(mktemp -d)"
ANVIL_LOG="${TMP_DIR}/anvil.log"
ANVIL_PID=""

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if [[ -n "$ANVIL_PID" ]] && kill -0 "$ANVIL_PID" 2>/dev/null; then
        kill "$ANVIL_PID" 2>/dev/null || true
        wait "$ANVIL_PID" 2>/dev/null || true
    fi

    rm -rf "$TMP_DIR"
    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

for command in anvil cast forge jq npm; do
    command -v "$command" >/dev/null || {
        echo "Missing required command: $command" >&2
        exit 1
    }
done

if [[ -z "${ETH_RPC_URL:-}" ]]; then
    echo "Please set ETH_RPC_URL to a Mainnet RPC URL" >&2
    exit 1
fi

if [[ "$(cast chain --rpc-url "$ETH_RPC_URL")" != "ethlive" ]]; then
    echo "ETH_RPC_URL must point to Ethereum Mainnet" >&2
    exit 1
fi

if cast chain-id --rpc-url "$LOCAL_RPC_URL" >/dev/null 2>&1; then
    echo "Port $ANVIL_PORT is already serving an Ethereum RPC" >&2
    exit 1
fi

anvil_args=(
    --fork-url "$ETH_RPC_URL"
    --chain-id 1
    --hardfork cancun
    --host 127.0.0.1
    --port "$ANVIL_PORT"
    --gas-limit 1000000000
)

if [[ -n "$FORK_BLOCK_NUMBER" ]]; then
    anvil_args+=(--fork-block-number "$FORK_BLOCK_NUMBER")
fi

echo "Starting Anvil fork at ${LOCAL_RPC_URL}..."
anvil "${anvil_args[@]}" >"$ANVIL_LOG" 2>&1 &
ANVIL_PID=$!

for _ in {1..60}; do
    if cast chain-id --rpc-url "$LOCAL_RPC_URL" >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
        echo "Anvil exited before becoming ready" >&2
        while IFS= read -r line; do
            printf '%s\n' "$line" >&2
        done <"$ANVIL_LOG"
        exit 1
    fi
    sleep 0.5
done

if [[ "$(cast chain-id --rpc-url "$LOCAL_RPC_URL")" != "1" ]]; then
    echo "Anvil fork did not start with chain ID 1" >&2
    exit 1
fi

echo "Installing SafeHarbor script dependencies..."
npm --prefix scripts/safeharbor --silent ci

echo "Deploying local DssSpell..."
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

echo "Giving local spell the Chief hat..."
cast rpc \
    --rpc-url "$LOCAL_RPC_URL" \
    anvil_setStorageAt \
    "$chief_address" \
    "$CHIEF_HAT_SLOT" \
    "$spell_hat_word" >/dev/null

hat_address="$(cast call --rpc-url "$LOCAL_RPC_URL" "$chief_address" "hat()(address)")"
if [[ "${hat_address,,}" != "${spell_address,,}" ]]; then
    echo "Local spell did not receive the Chief hat" >&2
    exit 1
fi

echo "Scheduling local spell..."
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

echo "Warping to ${next_cast_time} and casting local spell..."
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

echo "Checking SafeHarbor state..."
if safeharbor_output="$(
    ETH_RPC_URL="$LOCAL_RPC_URL" \
        npm --prefix scripts/safeharbor run --silent generate 2>&1
)"; then
    safeharbor_status=0
else
    safeharbor_status=$?
fi
printf '%s\n' "$safeharbor_output"

if ((safeharbor_status != 0)); then
    echo "SafeHarbor script failed" >&2
    exit "$safeharbor_status"
fi

if [[ "$safeharbor_output" != *"No updates to generate"* ]]; then
    echo "SafeHarbor state differs after local spell cast" >&2
    exit 1
fi

if [[ "$safeharbor_output" == *"⚠"* ]] || [[ "$safeharbor_output" == *"‼"* ]]; then
    echo "SafeHarbor validation warning found after local spell cast" >&2
    exit 1
fi

echo "SafeHarbor Anvil preflight passed"
