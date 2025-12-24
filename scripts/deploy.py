#! /usr/bin/env python3
"""
Automates deployment of the DssSpell contract, updates config with deployment details,
runs verification and tests, and commits the resulting changes.
"""

import re
import os
import sys
import subprocess
import json

# Define static variables
CHAIN_ID = "1"
PATH_TO_SPELL = "src/DssSpell.sol"
SPELL_CONTRACT_NAME = "DssSpell"
PATH_TO_CONFIG = "src/test/config.sol"

# Check for uncommitted changes
git_status = subprocess.run(
    ["git", "status", "--porcelain"], stdout=subprocess.PIPE, text=True, check=True
).stdout.strip()
if git_status:
    sys.exit(
        "There are uncommitted changes in the repository. Please commit or stash them before running this script"
    )

# Check env ETH_RPC_URL is set
ETH_RPC_URL = os.environ.get("ETH_RPC_URL")
if not ETH_RPC_URL:
    sys.exit("Please set ETH_RPC_URL environment variable with RPC url")

# Check ETH_RPC_URL is correct
cast_chain_id = subprocess.run(
    ["cast", "chain-id"], stdout=subprocess.PIPE, text=True, check=True
).stdout.strip()
if cast_chain_id != CHAIN_ID:
    sys.exit(
        f'Please provide correct ETH_RPC_URL. Currently set to chain id "{cast_chain_id}", expected "{CHAIN_ID}"'
    )
print(f"Using chain id {cast_chain_id}")

# Check env ETHERSCAN_API_KEY is set
ETHERSCAN_API_KEY = os.environ.get("ETHERSCAN_API_KEY")
if not ETHERSCAN_API_KEY:
    sys.exit("Please set ETHERSCAN_API_KEY environment variable")

# Check env ETH_KEYSTORE is set
ETH_KEYSTORE = os.environ.get("ETH_KEYSTORE")
if not ETH_KEYSTORE:
    # Use `cast wallet import --interactive "keystore_name"`
    sys.exit("Please set ETH_KEYSTORE environment variable with path to the keystore")

# Build deploy command
deploy_cmd = [
    "forge",
    "create",
    "--no-cache",
    "--broadcast",
    "--json",
    "--keystore",
    ETH_KEYSTORE,
    # Last argument is the contract itself
    f"{PATH_TO_SPELL}:{SPELL_CONTRACT_NAME}",
]

# Deploy the spell
print("Deploying a spell...")
deploy_logs = subprocess.run(
    deploy_cmd, stdout=subprocess.PIPE, text=True, check=True
).stdout
print(deploy_logs)


# Helper
def parse_json(raw_data: str, error_type: str):
    """Parses the string as JSON"""
    try:
        return json.loads(raw_data)
    except json.JSONDecodeError:
        sys.exit(f"Could not parse {error_type} as JSON")


# Get spell address
deploy_data = parse_json(deploy_logs, "forge create output")
spell_address = deploy_data.get("deployedTo")
if not spell_address:
    sys.exit("Could not find address of the deployed spell in the output")
print(f"Extracted spell address: {spell_address}")

# Get spell transaction
tx_hash = deploy_data.get("transactionHash")
if not tx_hash:
    sys.exit("Could not find transaction hash in the output")
print(f"Extracted transaction hash: {tx_hash}")

# Get deployed contract block number
tx_block = subprocess.run(
    ["cast", "tx", tx_hash, "blockNumber"],
    stdout=subprocess.PIPE,
    text=True,
    check=True,
).stdout.strip()
print(f"Fetched transaction block: {tx_block}")

# Get deployed contract timestamp
tx_timestamp = subprocess.run(
    ["cast", "block", "--field", "timestamp", "--json", tx_block],
    stdout=subprocess.PIPE,
    text=True,
    check=True,
).stdout.strip()
print(f"Fetched transaction timestamp: {tx_timestamp}")

# Read config
with open(PATH_TO_CONFIG, "r", encoding="utf-8") as f:
    config_content = f.read()

# Edit config
print(f'Editing config file "{PATH_TO_CONFIG}"...')
config_content = re.sub(
    r"(\s*deployed_spell:\s*).*(,)",
    r"\g<1>address(" + spell_address + r")\g<2>",
    config_content,
)
config_content = re.sub(
    r"(\s*deployed_spell_block:\s*).*(,)",
    r"\g<1>" + tx_block + r"\g<2>",
    config_content,
)
config_content = re.sub(
    r"(\s*deployed_spell_created:\s*).*(,)",
    r"\g<1>" + tx_timestamp + r"\g<2>",
    config_content,
)

# Write back to config
with open(PATH_TO_CONFIG, "w", encoding="utf-8") as f:
    f.write(config_content)

# Verify the contract
subprocess.run(
    [
        "make",
        "verify",
        f"addr={spell_address}",
    ],
    check=True,
)

# Re-run the tests
print("Re-running the tests...")
test_logs = subprocess.run(
    ["make", "test"], capture_output=True, text=True, check=False
)
print(test_logs.stdout)

if test_logs.returncode != 0:
    print(test_logs.stderr)
    print("Ensure Tests PASS before commiting the `config.sol` changes!")
    sys.exit(test_logs.returncode)

# Commit the changes
print("Commiting changes to the `config.sol`...")
subprocess.run(
    [
        "git",
        "commit",
        "-m",
        "add deployed spell info",
        "--",
        PATH_TO_CONFIG,
    ],
    check=True,
)
