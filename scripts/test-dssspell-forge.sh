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

# Compile the spell with the optimizer on (separate profile + out dir) so DssSpellAction fits under
# the EIP-170 size limit. The tests load this artifact via vm.deployCode. The test sources are skipped
# here because they do not compile with the optimizer on (stack too deep in the Safe Harbor checks).
FOUNDRY_PROFILE=optimized forge build --skip '*.t.sol' --skip '*.t.base.sol'

forge test --fork-url "$ETH_RPC_URL" $TEST_ARGS
