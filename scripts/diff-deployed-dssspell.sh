#!/usr/bin/env bash

set -e

command -v jq &> /dev/null || { echo '`jq` command could not be found. Please install it: https://github.com/stedolan/jq'; exit 1; }
[[ "$ETHERSCAN_API_KEY" ]] || { echo -e "Please set ETHERSCAN_API_KEY"; exit 1; }

if [[ "$1" =~  ^0x[0-9a-fA-F]{40}$ ]]; then
    deployed_spell_address=$1
else
    # Read contract address from config.sol
    deployed_spell_address=$(grep -oE 'deployed_spell:\s*(address\((0x[a-fA-F0-9]{40})\)|(0x[a-fA-F0-9]{40}))' "src/test/config.sol" | sed -E 's/.*(0x[a-fA-F0-9]{40}).*/\1/')
    # Check if contract address, block number, and timestamp are zero
    [[ "$deployed_spell_address" =~ ^(address\(0\)|0|0x0{40})$ ]] && { echo "DssSpell address is not set in config file."; exit 1; }
fi

make all && make flatten

spell_source="out/flat.sol"
etherscan_source="out/etherscan.sol"

# Download the deployed spell source code from Etherscan API
curl -s "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=${deployed_spell_address}&apikey=${ETHERSCAN_API_KEY}" \
    | jq -r '.result[0].SourceCode' > $etherscan_source

# Compare the downloaded source code with the local spell
# Notice: Etherscan apparently returns the source code with Windows-style ('\n\r') line breaks sometimes.
#   We use `--string-trailing-cr` to ignore any `\r` characters.
# Notice: With `printf` below we ignore any trailing empty lines.
diff --strip-trailing-cr --color -u <(printf "%s" "$(< $etherscan_source)") <(printf "%s" "$(< $spell_source)")

make clean
