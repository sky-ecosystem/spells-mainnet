#!/usr/bin/env bash

set -e

# Define Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

function success_check() {
  echo -e "[${GREEN}✔${NC}] ${GREEN}$1${NC}"
}

function error_check() {
  echo -e "[${RED}✖${NC}] ${RED}$1${NC}"
}

[[ "$ETH_RPC_URL" && "$(cast chain)" == "ethlive" && "$(cast chain-id)" == "1" ]] || { echo -e "Please set a Mainnet ETH_RPC_URL"; exit 1; }
[[ "$ETHERSCAN_API_KEY" ]] || { echo -e "Please set ETHERSCAN_API_KEY"; exit 1; }

# Etherscan API endpoint
ETHERSCAN_API="https://api.etherscan.io/v2/api?chainid=1&apikey=$ETHERSCAN_API_KEY"

# Path to config.sol file
CONFIG_PATH="src/test/config.sol"

# DssSpell data
LICENSE="GNU AGPLv3"
SOLC="v0.8.16+commit.07a7930e"

# Read spell address, block number, and timestamp from config.sol
deployed_spell_address=$(grep -oE 'deployed_spell:\s+address\((0x[a-fA-F0-9]+)\)' $CONFIG_PATH | grep -o '0x[a-fA-F0-9]\+')
deployed_spell_block=$(grep -oE 'deployed_spell_block\s*:\s*[0-9]+' $CONFIG_PATH | grep -o '[0-9]\+')
deployed_spell_timestamp=$(grep -oE 'deployed_spell_created\s*:\s*[0-9]+' $CONFIG_PATH | grep -o '[0-9]\+')

# Check if spell address, block number, and timestamp are zero
if [[ "$deployed_spell_address" =~ ^(address\(0\)|0)$ ]] || [[ "$deployed_spell_block" = "0" ]] || [[ "$deployed_spell_timestamp" = "0" ]]; then
  echo "DssSpell address, block number, or timestamp is not set in config file."
  exit 1
fi

# Get spell verification information
verified_spell_info=$(curl -s "$ETHERSCAN_API&module=contract&action=getsourcecode&address=$deployed_spell_address" | jq -r .result[0])

# Check spell verification status
verified=$(echo "$verified_spell_info" | jq -r '.SourceCode != null')
if [ "$verified" ]; then
  success_check "DssSpell is verified."
else
  error_check "DssSpell not verified."
fi

# Check verified spell license type
license_type=$(echo "$verified_spell_info" | jq -r '.LicenseType')
if [ "$license_type" == "$LICENSE" ]; then
  success_check "DssSpell was verified with a valid license."
else
  error_check "DssSpell was verified with an invalid or unknown license."
fi

# Check verified spell solc version
solc_version=$(echo "$verified_spell_info" | jq -r '.CompilerVersion')
if [ "$solc_version" == "$SOLC" ]; then
  success_check "DssSpell solc version matches."
else
  error_check "DssSpell solc version does not match."
fi

# Check verified spell optimizations
optimized=$(echo "$verified_spell_info" | jq -r '.OptimizationUsed == "1"')
if [ "$optimized" = "false" ]; then
  success_check "DssSpell was not compiled with optimizations."
else
  error_check "DssSpell was compiled with optimizations."
fi

# Check verified spell linked library
library_address=$(echo "$verified_spell_info" | jq -r '.Library | split(":") | .[1]')
checksum_library_address=$(cast --to-checksum-address "$library_address")
if [ "$checksum_library_address" == "$(cat foundry.toml | sed -nE 's/.*DssExecLib:(0x[0-9a-fA-F]{40}).*/\1/p')" ]; then
  success_check "DssSpell library matches hardcoded address in foundry.toml."
else
  error_check "DssSpell library does not match hardcoded address."
fi

# Retrieve transaction hash
tx_hash=$(curl -s "$ETHERSCAN_API&module=account&action=txlistinternal&address=$deployed_spell_address&startblock=0&endblock=99999999&sort=asc" | jq -r ".result[0].hash")

# Retrieve deployed spell timestamp and block number info
timestamp=$(cast block "$(cast tx "${tx_hash}"|grep blockNumber|awk '{print $2}')"|grep timestamp|awk '{print $2}')
block=$(cast tx "${tx_hash}"|grep blockNumber|awk '{print $2}')

# Check deployed spell timestamp
if [ "$timestamp" == "$deployed_spell_timestamp" ]; then
  success_check "DssSpell deployment timestamp matches."
else
  error_check "DssSpell deployment timestamp does not match."
fi

# Check deployed spell block number
if [ "$block" == "$deployed_spell_block" ]; then
  success_check "DssSpell deployment block number matches."
else
  error_check "DssSpell deployment block number does not match."
fi
