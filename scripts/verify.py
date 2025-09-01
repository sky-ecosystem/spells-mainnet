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

# Block explorer configurations
ETHERSCAN_API_URL = 'https://api.etherscan.io/v2/api'
SOURCIFY_API_URL = 'https://sourcify.dev/server'
ETHERSCAN_SUBDOMAINS = {
    '1': '',
    '11155111': 'sepolia.'
}
LICENSE_NUMBERS = {
    'GPL-3.0-or-later': 5,
    'AGPL-3.0-or-later': 13
}


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


class EtherscanVerifier:
    """Etherscan block explorer verifier."""
    
    def __init__(self, api_key: str, chain_id: str):
        self.api_key = api_key
        self.chain_id = chain_id
        self.subdomain = ETHERSCAN_SUBDOMAINS.get(chain_id, '')
    
    def is_available(self) -> bool:
        """Check if Etherscan supports this chain."""
        return self.chain_id in ETHERSCAN_SUBDOMAINS
    
    def get_verification_url(self, contract_address: str) -> str:
        """Get Etherscan URL for the verified contract."""
        return f"https://{self.subdomain}etherscan.io/address/{contract_address}#code"
    
    @retry_with_backoff(max_retries=3, base_delay=2, max_delay=30)
    def _send_api_request(self, params: Dict[str, str], data: Dict[str, Any]) -> Dict:
        """Send request to Etherscan API with retry mechanism."""
        headers = {'User-Agent': 'Sky-Protocol-Spell-Verifier'}
        
        response = requests.post(
            ETHERSCAN_API_URL,
            headers=headers,
            params=params,
            data=data,
            timeout=30
        )
        
        response.raise_for_status()
        
        try:
            return json.loads(response.text)
        except json.decoder.JSONDecodeError as e:
            print(f"Response text: {response.text}", file=sys.stderr)
            raise Exception(f'Etherscan responded with invalid JSON: {str(e)}')
    
    def _wait_for_verification(self, guid: str, params: Dict[str, str], code: str) -> None:
        """Wait for verification to complete with retry mechanism."""
        check_data = {
            'apikey': self.api_key,
            'module': 'contract',
            'action': 'checkverifystatus',
            'guid': guid,
        }
        
        check_response = {}
        max_attempts = 20
        
        for attempt in range(max_attempts):
            if check_response and 'pending' not in check_response.get('result', '').lower():
                break
                
            if check_response:
                print(check_response['result'], file=sys.stderr)
                print(f'Waiting for 15 seconds for Etherscan to process... (attempt {attempt + 1}/{max_attempts})', file=sys.stderr)
                time.sleep(15)
            
            try:
                check_response = self._send_api_request(params, check_data)
            except Exception as e:
                print(f"Error checking verification status: {str(e)}", file=sys.stderr)
                if attempt == max_attempts - 1:
                    raise
                time.sleep(15)
                continue
        
        if check_response['status'] != '1' or check_response['message'] != 'OK':
            if 'already verified' not in check_response['result'].lower():
                log_name = f'verify-etherscan-{datetime.now().timestamp()}.log'
                with open(log_name, 'w') as log:
                    log.write(code)
                print(f'Source code logged to {log_name}', file=sys.stderr)
                
                raise Exception(f'Verification failed: {check_response.get("result", "Unknown error")}')
            else:
                print('Contract is already verified')
    
    def verify_contract(
        self,
        contract_name: str,
        contract_address: str,
        source_code: str,
        constructor_args: str,
        metadata: Dict[str, Any],
        library_address: str = ""
    ) -> bool:
        """Verify contract on Etherscan."""
        print(f'\nVerifying {contract_name} at {contract_address} on Etherscan...')
        
        params = {'chainid': self.chain_id}
        
        license_name = metadata.get('license_name', 'MIT')
        license_number = LICENSE_NUMBERS.get(license_name, 1)
        
        data = {
            'apikey': self.api_key,
            'module': 'contract',
            'action': 'verifysourcecode',
            'contractaddress': contract_address,
            'sourceCode': source_code,
            'codeFormat': 'solidity-single-file',
            'contractName': contract_name,
            'compilerversion': metadata['compiler_version'],
            'optimizationUsed': '1' if metadata['optimizer_enabled'] else '0',
            'runs': metadata['optimizer_runs'],
            'constructorArguements': constructor_args,
            'evmversion': metadata['evm_version'],
            'licenseType': license_number,
        }
        
        if library_address:
            data['libraryname1'] = 'DssExecLib'
            data['libraryaddress1'] = library_address
        
        # Submit verification request with retry
        max_retries = 3
        for attempt in range(max_retries):
            try:
                verify_response = self._send_api_request(params, data)
                break
            except Exception as e:
                if attempt == max_retries - 1:
                    print(f"Failed to submit verification request after {max_retries} attempts: {str(e)}", file=sys.stderr)
                    return False
                print(f"Attempt {attempt + 1} failed, retrying...", file=sys.stderr)
                time.sleep(2 ** attempt)
        
        # Handle "contract not yet deployed" case
        max_deploy_retries = 5
        deploy_retry_count = 0
        
        while 'locate' in verify_response.get('result', '').lower() and deploy_retry_count < max_deploy_retries:
            print(verify_response['result'], file=sys.stderr)
            print(f'Waiting for 15 seconds for the network to update... (attempt {deploy_retry_count + 1}/{max_deploy_retries})', file=sys.stderr)
            time.sleep(15)
            
            try:
                verify_response = self._send_api_request(params, data)
            except Exception as e:
                print(f"Error during deploy retry: {str(e)}", file=sys.stderr)
                deploy_retry_count += 1
                continue
        
        if deploy_retry_count >= max_deploy_retries:
            print("Contract not found on network after maximum retries", file=sys.stderr)
            return False
        
        if verify_response['status'] != '1' or verify_response['message'] != 'OK':
            if 'already verified' in verify_response['result'].lower():
                print('Contract is already verified on Etherscan')
                return True
            print(f'Failed to submit verification request: {verify_response.get("result", "Unknown error")}', file=sys.stderr)
            return False
        
        guid = verify_response['result']
        print(f'Verification request submitted with GUID: {guid}')
        
        try:
            self._wait_for_verification(guid, params, source_code)
            print(f'Contract verified successfully at {self.get_verification_url(contract_address)}')
            return True
        except Exception as e:
            print(f"Verification failed: {str(e)}", file=sys.stderr)
            return False


class SourcifyVerifier:
    """Sourcify block explorer verifier."""
    
    def __init__(self, chain_id: str):
        self.chain_id = chain_id
    
    def is_available(self) -> bool:
        """Check if Sourcify supports this chain."""
        return self.chain_id in ['1', '11155111']  # Mainnet and Sepolia
    
    def get_verification_url(self, contract_address: str) -> str:
        """Get Sourcify URL for the verified contract."""
        return f"https://sourcify.dev/#/lookup/{contract_address}"
    
    @retry_with_backoff(max_retries=3, base_delay=2, max_delay=30)
    def _send_api_request(self, endpoint: str, data: Dict[str, Any]) -> Dict:
        """Send request to Sourcify API with retry mechanism."""
        headers = {
            'User-Agent': 'Sky-Protocol-Spell-Verifier',
            'Content-Type': 'application/json'
        }
        
        url = f"{SOURCIFY_API_URL}/{endpoint}"
        
        response = requests.post(
            url,
            headers=headers,
            json=data,
            timeout=30
        )
        
        response.raise_for_status()
        
        try:
            return response.json()
        except json.decoder.JSONDecodeError as e:
            print(f"Response text: {response.text}", file=sys.stderr)
            raise Exception(f'Sourcify responded with invalid JSON: {str(e)}')
    
    def verify_contract(
        self,
        contract_name: str,
        contract_address: str,
        source_code: str,
        constructor_args: str,
        metadata: Dict[str, Any],
        library_address: str = ""
    ) -> bool:
        """Verify contract on Sourcify."""
        print(f'\nVerifying {contract_name} at {contract_address} on Sourcify...')
        
        files_data = {
            "contract.sol": source_code
        }
        
        if metadata:
            files_data["metadata.json"] = json.dumps(metadata)
        
        verification_data = {
            "address": contract_address,
            "chain": self.chain_id,
            "files": files_data
        }
        
        if constructor_args:
            verification_data["constructorArgs"] = constructor_args
        
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = self._send_api_request("verify", verification_data)
                
                if response.get("status") == "perfect":
                    print(f'Contract verified successfully on Sourcify')
                    print(f'View at: {self.get_verification_url(contract_address)}')
                    return True
                elif response.get("status") == "partial":
                    print(f'Contract partially verified on Sourcify (some files missing)')
                    print(f'View at: {self.get_verification_url(contract_address)}')
                    return True
                else:
                    print(f'Verification failed: {response.get("message", "Unknown error")}', file=sys.stderr)
                    return False
                    
            except Exception as e:
                if attempt == max_retries - 1:
                    print(f"Failed to verify on Sourcify after {max_retries} attempts: {str(e)}", file=sys.stderr)
                    return False
                print(f"Attempt {attempt + 1} failed, retrying...", file=sys.stderr)
                time.sleep(2 ** attempt)
        
        return False


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
            return

        # Get and verify action contract
        action_address = get_action_address(spell_address)
        if not action_address:
            print('Could not determine action contract address', file=sys.stderr)
            return

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
            return

        print('\n🎉 All verifications complete!')
        
    except Exception as e:
        print(f'\nError: {str(e)}', file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
