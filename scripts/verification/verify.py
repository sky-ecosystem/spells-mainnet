#!/usr/bin/env python3
"""
Enhanced contract verification script for Sky Protocol spells on mainnet.
This script verifies both the DssSpell and DssSpellAction contracts on multiple block explorers
using forge verify-contract --flatten with robust retry mechanisms and fallback options.
"""
import os
import sys
import subprocess
from typing import Tuple, List

from . import get_chain_id, get_library_address, get_action_address

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


def build_forge_cmd(
    verifier: str,
    address: str,
    contract_name: str,
    constructor_args: str,
    library_address: str,
    retries: int,
    delay: int,
    etherscan_api_key: str = "",
) -> List[str]:
    cmd: List[str] = [
        "forge",
        "verify-contract",
        address,
        f"{SOURCE_FILE_PATH}:{contract_name}",
        "--verifier",
        verifier,
        "--flatten",
        "--watch",
        "--retries",
        str(retries),
        "--delay",
        str(delay),
    ]

    if constructor_args:
        cmd.extend(["--constructor-args", constructor_args])

    if library_address:
        cmd.extend(["--libraries", f"src/DssExecLib.sol:DssExecLib:{library_address}"])

    if verifier == "etherscan" and etherscan_api_key:
        cmd.extend(["--etherscan-api-key", etherscan_api_key])

    return cmd


def verify_once_on(
    verifier: str,
    address: str,
    contract_name: str,
    constructor_args: str,
    library_address: str,
    retries: int,
    delay: int,
    etherscan_api_key: str = "",
) -> bool:
    cmd = build_forge_cmd(
        verifier=verifier,
        address=address,
        contract_name=contract_name,
        constructor_args=constructor_args,
        library_address=library_address,
        retries=retries,
        delay=delay,
        etherscan_api_key=etherscan_api_key,
    )

    print(f"\nVerifying {contract_name} at {address} on {verifier}...")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
        # forge prints useful info; surface stdout
        if result.stdout:
            print(result.stdout.strip())
        print(f"✓ {verifier} verification OK")
        return True
    except subprocess.CalledProcessError as e:
        combined = (e.stdout or "") + "\n" + (e.stderr or "")
        if "already verified" in combined.lower():
            print(f"✓ {verifier}: already verified")
            return True
        print(f"✗ {verifier} verification failed\n{combined}", file=sys.stderr)
        return False


def verify_contract_with_verifiers(
    contract_name: str,
    contract_address: str,
    constructor_args: str,
    library_address: str
) -> bool:
    """Verify contract by issuing forge commands per explorer."""
    # Configure retries/delay via env or defaults
    retries = int(os.environ.get("VERIFY_RETRIES", "5"))
    delay = int(os.environ.get("VERIFY_DELAY", "5"))

    chain_id = get_chain_id()
    etherscan_api_key = os.environ.get("ETHERSCAN_API_KEY", "")

    successes = 0

    # Sourcify (works without API key); blockscout pulls from it
    if chain_id == "1":
        if verify_once_on(
            verifier="sourcify",
            address=contract_address,
            contract_name=contract_name,
            constructor_args=constructor_args,
            library_address=library_address,
            retries=retries,
            delay=delay,
        ):
            successes += 1
    else:
        print(f"Sourcify not configured for CHAIN_ID {chain_id}, skipping.")

    # Etherscan (requires API key)
    if chain_id == "1" and etherscan_api_key:
        if verify_once_on(
            verifier="etherscan",
            address=contract_address,
            contract_name=contract_name,
            constructor_args=constructor_args,
            library_address=library_address,
            retries=retries,
            delay=delay,
            etherscan_api_key=etherscan_api_key,
        ):
            successes += 1
    elif chain_id == "1":
        print("ETHERSCAN_API_KEY not set; skipping Etherscan.")

    return successes > 0


def main():
    """Main entry point for the enhanced verification script."""
    try:
        # Get environment variables
        get_env_var(
            'ETH_RPC_URL',
            "You need a valid ETH_RPC_URL.\n"
            "Get a public one at https://chainlist.org/ or provide your own\n"
            "Then export it with `export ETH_RPC_URL=https://....'"
        )

        # Parse command line arguments
        spell_name, spell_address, constructor_args = parse_command_line_args()

        # Get library address
        library_address = get_library_address()

        # Verify spell contract
        spell_success = verify_contract_with_verifiers(
            contract_name=spell_name,
            contract_address=spell_address,
            constructor_args=constructor_args,
            library_address=library_address
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
            constructor_args=constructor_args,
            library_address=library_address
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


