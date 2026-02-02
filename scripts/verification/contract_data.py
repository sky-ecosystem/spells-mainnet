#!/usr/bin/env python3
"""
Contract data utilities for Sky Protocol spells verification.
This module handles contract metadata extraction, source code flattening,
and other contract-related data operations.
"""
import os
import subprocess
import sys
from typing import Optional

# Constants
SOURCE_FILE_PATH = "src/DssSpell.sol"
LIBRARY_NAME = "DssExecLib"


def get_chain_id() -> str:
    """Get the current chain ID."""
    print("Obtaining chain ID... ")
    result = subprocess.run(
        ["cast", "chain-id"], capture_output=True, text=True, check=True
    )
    chain_id = result.stdout.strip()
    print(f"CHAIN_ID: {chain_id}")
    return chain_id

def get_action_address(spell_address: str) -> Optional[str]:
    """Get the action contract address from the spell contract."""
    try:
        result = subprocess.run(
            ["cast", "call", spell_address, "action()(address)"],
            capture_output=True,
            text=True,
            check=True,
            env=os.environ | {"ETH_GAS_PRICE": "0", "ETH_PRIO_FEE": "0"},
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error getting action address: {str(e)}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Unexpected error getting action address: {str(e)}", file=sys.stderr)
        return None
