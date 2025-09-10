#!/usr/bin/env python3
"""
Contract data utilities for Sky Protocol spells verification.
This module handles contract metadata extraction, source code flattening,
and other contract-related data operations.
"""
import os
import sys
import subprocess
import re
import json
from typing import Dict, Any, Optional

from .retry import retry_with_backoff


# Constants
FLATTEN_OUTPUT_PATH = 'out/flat.sol'
SOURCE_FILE_PATH = 'src/DssSpell.sol'
LIBRARY_NAME = 'DssExecLib'


@retry_with_backoff(max_retries=2, base_delay=1)
def get_chain_id() -> str:
    """Get the current chain ID with retry mechanism."""
    print('Obtaining chain ID... ')
    result = subprocess.run(['cast', 'chain-id'], capture_output=True, text=True, check=True)
    chain_id = result.stdout.strip()
    print(f"CHAIN_ID: {chain_id}")
    return chain_id


def get_library_address() -> str:
    """Find the DssExecLib address from either DssExecLib.address file or foundry.toml."""
    library_address = ''

    # First try to read from foundry.toml libraries
    if os.path.exists('foundry.toml'):
        try:
            with open('foundry.toml', 'r') as f:
                config = f.read()

            result = re.search(r':DssExecLib:(0x[0-9a-fA-F]{40})', config)
            if result:
                library_address = result.group(1)
                print(f'Using library {LIBRARY_NAME} at address {library_address}')
                return library_address
            else:
                print('No DssExecLib configured in foundry.toml', file=sys.stderr)
        except Exception as e:
            print(f'Error reading foundry.toml: {str(e)}', file=sys.stderr)
    else:
        print('No foundry.toml found', file=sys.stderr)

    # If it cannot be found, try DssExecLib.address
    if os.path.exists('DssExecLib.address'):
        try:
            print(f'Trying to read DssExecLib.address...', file=sys.stderr)
            with open('DssExecLib.address', 'r') as f:
                library_address = f.read().strip()
            print(f'Using library {LIBRARY_NAME} at address {library_address}')
            return library_address
        except Exception as e:
            print(f'Error reading DssExecLib.address: {str(e)}', file=sys.stderr)

    # If we get here, no library address was found
    print('WARNING: Assuming this contract uses no libraries', file=sys.stderr)
    return ''


@retry_with_backoff(max_retries=2, base_delay=1)
def flatten_source_code() -> None:
    """Flatten the source code using Forge with retry mechanism."""
    result = subprocess.run([
        'forge', 'flatten',
        SOURCE_FILE_PATH,
        '--output', FLATTEN_OUTPUT_PATH
    ], capture_output=True, text=True, check=True)

    if result.returncode != 0:
        raise Exception(f"Forge flatten failed: {result.stderr}")


def get_contract_metadata(output_path: str, input_path: str) -> Dict[str, Any]:
    """Extract contract metadata from the compiled output."""
    try:
        with open(output_path, 'r') as f:
            content = json.load(f)

        metadata = content['metadata']
        license_name = metadata['sources'][input_path]['license']

        return {
            'compiler_version': 'v' + metadata['compiler']['version'],
            'evm_version': metadata['settings']['evmVersion'],
            'optimizer_enabled': metadata['settings']['optimizer']['enabled'],
            'optimizer_runs': metadata['settings']['optimizer']['runs'],
            'license_name': license_name
        }
    except FileNotFoundError:
        raise Exception('Run forge build first')
    except json.decoder.JSONDecodeError:
        raise Exception('Run forge build again')
    except KeyError as e:
        raise Exception(f'Missing metadata field: {e}')


def read_flattened_code() -> str:
    """Read the flattened source code."""
    try:
        with open(FLATTEN_OUTPUT_PATH, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        raise Exception(f'Flattened source code not found at {FLATTEN_OUTPUT_PATH}. Run forge flatten first.')
    except UnicodeDecodeError as e:
        raise Exception(f'Error reading flattened source code: {str(e)}')


@retry_with_backoff(max_retries=2, base_delay=1)
def get_action_address(spell_address: str) -> Optional[str]:
    """Get the action contract address from the spell contract with retry mechanism."""
    try:
        result = subprocess.run(
            ['cast', 'call', spell_address, 'action()(address)'],
            capture_output=True,
            text=True,
            check=True,
            env=os.environ | {
                'ETH_GAS_PRICE': '0',
                'ETH_PRIO_FEE': '0'
            }
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f'Error getting action address: {str(e)}', file=sys.stderr)
        return None
    except Exception as e:
        print(f'Unexpected error getting action address: {str(e)}', file=sys.stderr)
        return None
