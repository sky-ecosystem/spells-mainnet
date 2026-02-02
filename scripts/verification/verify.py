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

from . import get_chain_id, get_action_address

# Constants
SOURCE_FILE_PATH = 'src/DssSpell.sol'


def get_env_var(var_name: str, error_message: str) -> str:
    """Get environment variable with error handling."""
    try:
        return os.environ[var_name]
    except KeyError:
        print(f"  {error_message}", file=sys.stderr)
        sys.exit(1)


def parse_command_line_args() -> Tuple[str, str]:
    """Parse command line arguments."""
    if len(sys.argv) != 3:
        print("""usage:
./verify.py <contractname> <address>
""", file=sys.stderr)
        sys.exit(1)

    contract_name = sys.argv[1]
    contract_address = sys.argv[2]

    if len(contract_address) != 42:
        sys.exit('Malformed address')

    return contract_name, contract_address


def build_forge_cmd(
    verifier: str,
    address: str,
    contract_name: str,
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

    if verifier == "etherscan" and etherscan_api_key:
        cmd.extend(["--etherscan-api-key", etherscan_api_key])

    return cmd


def verify_once_on(
    verifier: str,
    address: str,
    contract_name: str,
    retries: int,
    delay: int,
    etherscan_api_key: str = "",
) -> bool:
    cmd = build_forge_cmd(
        verifier=verifier,
        address=address,
        contract_name=contract_name,
        retries=retries,
        delay=delay,
        etherscan_api_key=etherscan_api_key,
    )

    print(f"\nVerifying {contract_name} at {address} on {verifier}...")
    # Workaround for Forge bug: when ETHERSCAN_API_KEY is set, Forge ignores
    # --verifier sourcify and uses Etherscan (see foundry-rs/foundry
    # crates/verify/src/provider.rs client() step 4). Unset it for Sourcify
    # so Forge actually verifies on Sourcify.
    env = os.environ.copy()
    if verifier == "sourcify" and "ETHERSCAN_API_KEY" in env:
        del env["ETHERSCAN_API_KEY"]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            env=env,
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
    chain_id: str,
    etherscan_api_key: str,
    retries: int,
    delay: int,
) -> bool:
    """Verify contract by issuing forge commands per explorer."""
    successes = 0

    # Sourcify (works without API key); blockscout pulls from it
    if chain_id == "1":
        if verify_once_on(
            verifier="sourcify",
            address=contract_address,
            contract_name=contract_name,
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
        spell_name, spell_address = parse_command_line_args()

        # Parse configuration from environment
        chain_id = get_chain_id()
        etherscan_api_key = os.environ.get("ETHERSCAN_API_KEY", "")
        retries = int(os.environ.get("VERIFY_RETRIES", "5"))
        delay = int(os.environ.get("VERIFY_DELAY", "5"))

        # Verify spell contract
        spell_success = verify_contract_with_verifiers(
            contract_name=spell_name,
            contract_address=spell_address,
            chain_id=chain_id,
            etherscan_api_key=etherscan_api_key,
            retries=retries,
            delay=delay,
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
            chain_id=chain_id,
            etherscan_api_key=etherscan_api_key,
            retries=retries,
            delay=delay,
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


