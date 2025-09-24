#!/usr/bin/env python3
"""
Enhanced contract verification script for Sky Protocol spells.
This script verifies both the DssSpell and DssSpellAction contracts on multiple block explorers
with robust retry mechanisms and fallback options.
"""
import os
import sys
import time
from pathlib import Path
from typing import Dict, Any, Tuple, List


def add_project_root_to_path():
    """Add the project root directory to Python's module search path."""
    project_root = Path(__file__).parent.parent.resolve()
    if str(project_root) not in sys.path:
        sys.path.append(str(project_root))


# Add the project root to the Python path for imports
add_project_root_to_path()

# Import verifiers and contract data utilities from the verification package

from scripts.verification import (
    EtherscanVerifier,
    SourcifyVerifier,
    get_chain_id,
    get_library_address,
    flatten_source_code,
    get_contract_metadata,
    read_flattened_code,
    get_action_address
)

# Constants
SOURCE_FILE_PATH = 'src/DssSpell.sol'


def get_env_var(var_name: str, error_message: str) -> str:
    """Get environment variable with error handling."""
    try:
        return os.environ[var_name]
    except KeyError:
        print(f"  {error_message}", file=sys.stderr)
        sys.exit(1)


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
            else:
                print(f"✗ Verification failed on {verifier.__class__.__name__}")
                
        except Exception as e:
            print(f"✗ Error during verification with {verifier.__class__.__name__}: {str(e)}", file=sys.stderr)
    
    # Report final results after trying all verifiers
    if successful_verifications == 0:
        print(f"\n❌ Failed to verify contract on any verifier ({total_verifiers} attempted)")
        return False
    else:
        print(f"\n🎉 Contract verified successfully on {successful_verifications}/{total_verifiers} verifiers!")
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
