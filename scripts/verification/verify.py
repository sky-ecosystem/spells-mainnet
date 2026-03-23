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

from contract_data import get_chain_id, get_action_address

# Constants
SOURCE_FILE_PATH = "src/DssSpell.sol"


def require_env_var(var_name: str, error_message: str) -> None:
    """Exit with a helpful message when a required env var is missing."""
    if not os.environ.get(var_name):
        print(f"  {error_message}", file=sys.stderr)
        sys.exit(1)


def parse_command_line_args() -> Tuple[str, str]:
    """Parse command line arguments."""
    if len(sys.argv) != 3:
        print(
            """usage:
./verify.py <contractname> <address>
""",
            file=sys.stderr,
        )
        sys.exit(1)

    contract_name = sys.argv[1]
    contract_address = sys.argv[2]

    if len(contract_address) != 42:
        sys.exit("Malformed address")

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
    # --verifier sourcify and uses Etherscan (see
    # https://github.com/foundry-rs/foundry/issues/10774)
    # Unset it for Sourcify so Forge actually verifies on Sourcify.
    env = os.environ | {"ETHERSCAN_API_KEY": ""} if verifier == "sourcify" else os.environ

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
    except FileNotFoundError:
        print("✗ forge not found in PATH", file=sys.stderr)
        return False

    stdout = result.stdout or ""
    stderr = result.stderr or ""
    combined = f"{stdout}\n{stderr}".strip()
    combined_lower = combined.lower()

    # Surface forge output for easier debugging.
    if stdout:
        print(stdout.strip())
    if stderr:
        print(stderr.strip(), file=sys.stderr)

    if "already verified" in combined_lower:
        print(f"✓ {verifier}: already verified")
        return True

    if result.returncode != 0:
        print(f"✗ {verifier} verification failed", file=sys.stderr)
        return False

    # Guard against false-positives where forge returns 0 but output indicates failure.
    failure_markers = (
        "failed to verify",
        "verification failed",
        "unable to verify",
        "not verified",
    )
    if any(marker in combined_lower for marker in failure_markers):
        print(f"✗ {verifier} verification failed", file=sys.stderr)
        return False

    print(f"✓ {verifier} verification OK")
    return True


def verify_contract_with_verifiers(
    contract_name: str,
    contract_address: str,
    chain_id: str,
    etherscan_api_key: str,
    retries: int,
    delay: int,
) -> bool:
    """Verify contract by issuing forge commands per explorer."""
    attempted = 0
    successes = 0

    # Sourcify (works without API key); blockscout pulls from it
    if chain_id == "1":
        attempted += 1
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
        attempted += 1
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

    if successes == 0:
        return False

    if attempted > successes:
        print(
            (
                f"Warning: verification partially succeeded for {contract_name} "
                f"({successes}/{attempted} explorers)."
            ),
            file=sys.stderr,
        )

    return True


def main():
    """Main entry point for the enhanced verification script."""
    try:
        # Required env vars
        require_env_var(
            "ETH_RPC_URL",
            "You need a valid ETH_RPC_URL.\n"
            "Get a public one at https://chainlist.org/ or provide your own\n"
            "Then export it with `export ETH_RPC_URL=https://....'",
        )

        # Parse command line arguments
        spell_name, spell_address = parse_command_line_args()

        # Parse configuration from environment
        chain_id = get_chain_id()
        # Optional on mainnet; verification still succeeds via Sourcify without it.
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
            print("Could not determine action contract address", file=sys.stderr)
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

        print("\n🎉 All verifications complete!")

    except Exception as e:
        print(f"\nError: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
