#!/usr/bin/env bash
set -e

[[ "$(cast chain --rpc-url="$ETH_RPC_URL")" == "ethlive" ]] || { echo "Please set a mainnet ETH_RPC_URL"; exit 1; }

for ARGUMENT in "$@"
do
    KEY=$(echo "$ARGUMENT" | cut -f1 -d=)
    VALUE=$(echo "$ARGUMENT" | cut -f2 -d=)

    case "$KEY" in
            match)      MATCH="$VALUE" ;;
            no-match)   NO_MATCH="$VALUE" ;;
            block)      BLOCK="$VALUE" ;;
            *)
    esac
done

export FOUNDRY_ROOT_CHAINID=1

TEST_ARGS=''

if [[ -n "$MATCH" ]]; then
    TEST_ARGS="${TEST_ARGS} -vvv --match-test ${MATCH}"
elif [[ -n "$NO_MATCH" ]]; then
    TEST_ARGS="${TEST_ARGS} -vvv --no-match-test ${NO_MATCH}"
fi

if [[ -n "$BLOCK" ]]; then
    TEST_ARGS="${TEST_ARGS} --fork-block-number ${BLOCK}"
fi

forge test --fork-url "$ETH_RPC_URL" $TEST_ARGS
