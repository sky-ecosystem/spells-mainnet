#!/usr/bin/env python3
"""
Helpers to query on-chain data needed during spell verification (chain ID, action address).
"""
import os
import subprocess
import sys
from typing import Optional


def get_chain_id() -> str:
    """Get the current chain ID via ``cast chain-id``."""
    print("Obtaining chain ID... ")
    try:
        result = subprocess.run(
            ["cast", "chain-id"], capture_output=True, text=True, check=True
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(
            f"Failed to get chain ID — is ETH_RPC_URL valid and cast installed?\n  {e}",
            file=sys.stderr,
        )
        sys.exit(1)
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
