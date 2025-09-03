#!/usr/bin/env python3
"""
Enhanced contract verification script for Sky Protocol spells.
This script verifies both the DssSpell and DssSpellAction contracts on multiple block explorers
with robust retry mechanisms and fallback options.
"""
import os
import sys
import subprocess
import time
import re
import json
import requests
import random
from datetime import datetime
from typing import Dict, Any, Tuple, Optional, List, Callable
from functools import wraps

# Import verifiers from the verification package
from verification import EtherscanVerifier, SourcifyVerifier

# Constants
FLATTEN_OUTPUT_PATH = 'out/flat.sol'
SOURCE_FILE_PATH = 'src/DssSpell.sol'
LIBRARY_NAME = 'DssExecLib'

# Retry configuration
DEFAULT_MAX_RETRIES = 3
DEFAULT_BASE_DELAY = 2  # seconds
DEFAULT_MAX_DELAY = 60  # seconds
DEFAULT_BACKOFF_FACTOR = 2
DEFAULT_JITTER = 0.1  # 10% jitter




def retry_with_backoff(
    max_retries: int = DEFAULT_MAX_RETRIES,
    base_delay: float = DEFAULT_BASE_DELAY,
    max_delay: float = DEFAULT_MAX_DELAY,
    backoff_factor: float = DEFAULT_BACKOFF_FACTOR,
    jitter: float = DEFAULT_JITTER,
    exceptions: Tuple[Exception, ...] = (requests.RequestException, json.JSONDecodeError, Exception)
):
    """
    Decorator that implements exponential backoff with jitter for retrying functions.
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    
                    if attempt == max_retries:
                        print(f"Failed after {max_retries + 1} attempts. Last error: {str(e)}", file=sys.stderr)
                        raise
                    
                    # Calculate delay with exponential backoff and jitter
                    delay = min(base_delay * (backoff_factor ** attempt), max_delay)
                    jitter_amount = delay * jitter * random.uniform(-1, 1)
                    actual_delay = max(0, delay + jitter_amount)
                    
                    print(f"Attempt {attempt + 1} failed: {str(e)}", file=sys.stderr)
                    print(f"Retrying in {actual_delay:.2f} seconds... (attempt {attempt + 2}/{max_retries + 1})", file=sys.stderr)
                    
                    time.sleep(actual_delay)
            
            raise last_exception
        return wrapper
    return decorator


def get_env_var(var_name: str, error_message: str) -> str:
    """Get environment variable with error handling."""
    try:
        return os.environ[var_name]
    except KeyError:
        print(f"  {error_message}", file=sys.stderr)
        sys.exit(1)


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


def parse_command_line_args() -> Tuple[str, str, str]:
    """Parse command line arguments."""
    if len(sys.argv) not in [3, 4]:
        print("""usage:
./verify.py <contractname> <address> [constructorArgs]
""", file=sys.stderr)
        sys.exit(1)

    contract_name = sys.argv[1]
    contract_address = sys.argv[2]

    if len(contract_address) != 42:
        sys.exit('Malformed address')

    constructor_args = ''
    if len(sys.argv) == 4:
        constructor_args = sys.argv[3]

    return contract_name, contract_address, constructor_args


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


def setup_verifiers(chain_id: str) -> List[Any]:
    """Setup available verifiers for the given chain."""
    verifiers = []
    
    # Setup Etherscan verifier
    try:
        etherscan_api_key = get_env_var(
            'ETHERSCAN_API_KEY',
            "Etherscan API key not found. Set ETHERSCAN_API_KEY environment variable."
        )
        etherscan_verifier = EtherscanVerifier(etherscan_api_key, chain_id)
        if etherscan_verifier.is_available():
            verifiers.append(etherscan_verifier)
            print(f"✓ Etherscan verifier available for chain {chain_id}")
        else:
            print(f"✗ Etherscan verifier not available for chain {chain_id}")
    except Exception as e:
        print(f"✗ Failed to setup Etherscan verifier: {str(e)}", file=sys.stderr)
    
    # Setup Sourcify verifier
    # Note: Blockscout automatically picks up any code verification from Sourcify
    try:
        sourcify_verifier = SourcifyVerifier(chain_id)
        if sourcify_verifier.is_available():
            verifiers.append(sourcify_verifier)
            print(f"✓ Sourcify verifier available for chain {chain_id}")
        else:
            print(f"✗ Sourcify verifier not available for chain {chain_id}")
    except Exception as e:
        print(f"✗ Failed to setup Sourcify verifier: {str(e)}", file=sys.stderr)
    
    if not verifiers:
        raise Exception("No verifiers available for the current chain")
    
    return verifiers


def verify_contract_with_verifiers(
    contract_name: str,
    contract_address: str,
    source_code: str,
    constructor_args: str,
    metadata: Dict[str, Any],
    library_address: str,
    verifiers: List[Any]
) -> bool:
    """Verify contract using multiple verifiers with fallback."""
    print(f'\nVerifying {contract_name} at {contract_address}...')
    
    successful_verifications = 0
    total_verifiers = len(verifiers)
    
    for i, verifier in enumerate(verifiers):
        print(f"\n--- Attempting verification with {verifier.__class__.__name__} ({i+1}/{total_verifiers}) ---")
        
        try:
            success = verifier.verify_contract(
                contract_name=contract_name,
                contract_address=contract_address,
                source_code=source_code,
                constructor_args=constructor_args,
                metadata=metadata,
                library_address=library_address
            )
            
            if success:
                successful_verifications += 1
                print(f"✓ Successfully verified on {verifier.__class__.__name__}")
                
                if successful_verifications >= 1:
                    print(f"\n🎉 Contract verified successfully on {successful_verifications}/{total_verifiers} verifiers!")
                    return True
            else:
                print(f"✗ Verification failed on {verifier.__class__.__name__}")
                
        except Exception as e:
            print(f"✗ Error during verification with {verifier.__class__.__name__}: {str(e)}", file=sys.stderr)
        
        if i < total_verifiers - 1:
            print("Waiting 2 seconds before trying next verifier...")
            time.sleep(2)
    
    if successful_verifications == 0:
        print(f"\n❌ Failed to verify contract on any verifier ({total_verifiers} attempted)")
        return False
    
    return True


def main():
    """Main entry point for the enhanced verification script."""
    try:
        # Get environment variables
        rpc_url = get_env_var(
            'ETH_RPC_URL',
            "You need a valid ETH_RPC_URL.\n"
            "Get a public one at https://chainlist.org/ or provide your own\n"
            "Then export it with `export ETH_RPC_URL=https://....'"
        )

        # Parse command line arguments
        spell_name, spell_address, constructor_args = parse_command_line_args()

        # Get chain ID
        chain_id = get_chain_id()

        # Get library address
        library_address = get_library_address()

        # Setup verifiers
        print("Setting up verifiers...")
        verifiers = setup_verifiers(chain_id)

        # Flatten source code
        print("Flattening source code...")
        flatten_source_code()

        # Read flattened code
        source_code = read_flattened_code()

        # Get contract metadata
        metadata = get_contract_metadata(
            f'out/DssSpell.sol/DssSpell.json',
            SOURCE_FILE_PATH
        )

        # Verify spell contract
        spell_success = verify_contract_with_verifiers(
            contract_name=spell_name,
            contract_address=spell_address,
            source_code=source_code,
            constructor_args=constructor_args,
            metadata=metadata,
            library_address=library_address,
            verifiers=verifiers
        )

        if not spell_success:
            print("Failed to verify spell contract", file=sys.stderr)
            sys.exit(1)

        # Get and verify action contract
        action_address = get_action_address(spell_address)
        if not action_address:
            print('Could not determine action contract address', file=sys.stderr)
            sys.exit(1)

        action_success = verify_contract_with_verifiers(
            contract_name="DssSpellAction",
            contract_address=action_address,
            source_code=source_code,
            constructor_args=constructor_args,
            metadata=metadata,
            library_address=library_address,
            verifiers=verifiers
        )

        if not action_success:
            print("Failed to verify action contract", file=sys.stderr)
            sys.exit(1)

        print('\n🎉 All verifications complete!')
        
    except Exception as e:
        print(f'\nError: {str(e)}', file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
