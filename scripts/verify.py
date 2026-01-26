#!/usr/bin/env python3
"""
Contract verification script for Sky Protocol spells on Etherscan.
This script verifies both the DssSpell and DssSpellAction contracts.
"""
import os
import sys
import subprocess
import time
import re
import json
import requests
from datetime import datetime
from typing import Dict, Any, Tuple, Optional

# Constants
ETHERSCAN_API_URL = 'https://api.etherscan.io/v2/api'
FLATTEN_OUTPUT_PATH = 'out/flat.sol'
SOURCE_FILE_PATH = 'src/DssSpell.sol'
LIBRARY_NAME = 'DssExecLib'
ETHERSCAN_SUBDOMAINS = {
    '1': ''
}
LICENSE_NUMBERS = {
    'GPL-3.0-or-later': 5,
    'AGPL-3.0-or-later': 13
}


def get_env_var(var_name: str, error_message: str) -> str:
    """
    Get environment variable with error handling.
    """
    try:
        return os.environ[var_name]
    except KeyError:
        print(f"  {error_message}", file=sys.stderr)
        sys.exit(1)


def get_chain_id() -> str:
    """
    Get the current chain ID.
    """
    print('Obtaining chain ID... ')
    result = subprocess.run(['cast', 'chain-id'], capture_output=True)
    chain_id = result.stdout.decode('utf-8').strip()
    print(f"CHAIN_ID: {chain_id}")
    return chain_id


def get_library_address() -> str:
    """
    Find the DssExecLib address inside foundry.toml.
    Returns an empty string if no library address is found.
    """
    library_address = ''

    # Try to read from foundry.toml libraries
    try:
        with open('foundry.toml', 'r', encoding='utf-8') as f:
            config = f.read()
    except OSError as e:
        print(f'Error reading foundry.toml', file=sys.stderr)
        raise e

    result = re.search(r':DssExecLib:(0x[0-9a-fA-F]{40})', config)
    if result:
        library_address = result.group(1)
        print(
            f'Using library {LIBRARY_NAME} at address {library_address}')
        return library_address
    else:
        raise Exception('No DssExecLib configured in foundry.toml')


def parse_command_line_args() -> Tuple[str, str, str]:
    """
    Parse command line arguments.
    """
    if len(sys.argv) not in [3, 4]:
        print("""usage:\n
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


def flatten_source_code() -> None:
    """
    Flatten the source code using Forge.
    """
    subprocess.run([
        'forge', 'flatten',
        SOURCE_FILE_PATH,
        '--output', FLATTEN_OUTPUT_PATH
    ], capture_output=True)


def send_etherscan_api_request(params: Dict[str, str], data: Dict[str, Any]) -> Dict:
    """
    Sends the verification request to the Etherscan API
    """
    headers = {'User-Agent': 'Sky-Protocol-Spell-Verifier'}

    print('Sending verification request...', file=sys.stderr)
    response = requests.post(
        ETHERSCAN_API_URL, headers=headers, params=params, data=data)

    try:
        return json.loads(response.text)
    except json.decoder.JSONDecodeError:
        print(response.text, file=sys.stderr)
        raise Exception('Error: Etherscan responded with invalid JSON.')


def get_contract_metadata(output_path: str, input_path: str) -> Dict[str, Any]:
    """
    Extract contract metadata from the compiled output.
    """
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
            # Default to AGPL-3.0-or-later if unknown
            'license_number': LICENSE_NUMBERS.get(license_name, LICENSE_NUMBERS['AGPL-3.0-or-later'])
        }
    except FileNotFoundError:
        raise Exception('Run `forge build` and try again')
    except json.decoder.JSONDecodeError:
        raise Exception(f'Malformed JSON in {output_path}. Run `forge build --force` and try again')
    except KeyError as e:
        raise Exception(f'Missing metadata field: {e}')


def read_flattened_code() -> str:
    """
    Read the flattened source code.
    """
    with open(FLATTEN_OUTPUT_PATH, 'r', encoding='utf-8') as f:
        return f.read()


def prepare_verification_data(
    contract_name: str,
    contract_address: str,
    input_path: str,
    output_path: str,
    chain_id: str,
    api_key: str,
    constructor_args: str,
    library_address: str
) -> Tuple[Dict[str, str], Dict[str, Any], str]:
    """
    Prepare data for contract verification.
    """
    # Get contract metadata
    metadata = get_contract_metadata(output_path, input_path)

    # Read flattened source code
    code = read_flattened_code()

    # Prepare API request parameters
    params = {'chainid': chain_id}

    data = {
        'apikey': api_key,
        'module': 'contract',
        'action': 'verifysourcecode',
        'contractaddress': contract_address,
        'sourceCode': code,
        'codeFormat': 'solidity-single-file',
        'contractName': contract_name,
        'compilerversion': metadata['compiler_version'],
        'optimizationUsed': '1' if metadata['optimizer_enabled'] else '0',
        'runs': metadata['optimizer_runs'],
        'constructorArguements': constructor_args,
        'evmversion': metadata['evm_version'],
        'licenseType': metadata['license_number'],
        'libraryname1': LIBRARY_NAME,
        'libraryaddress1': library_address,
    }

    return params, data, code


def wait_for_verification(guid: str, params: Dict[str, str], api_key: str, code: str) -> None:
    """
    Wait for verification to complete and check status.
    """
    check_data = {
        'apikey': api_key,
        'module': 'contract',
        'action': 'checkverifystatus',
        'guid': guid,
    }

    check_response = {}

    # Poll until verification is complete
    while check_response == {} or 'pending' in check_response.get('result', '').lower():
        if check_response != {}:
            print(check_response['result'], file=sys.stderr)
            print(
                'Waiting for 15 seconds for Etherscan to process the request...',
                file=sys.stderr
            )
            time.sleep(15)

        check_response = send_etherscan_api_request(
            params=params, data=check_data)

    # Check verification result
    if check_response['status'] != '1' or check_response['message'] != 'OK':
        if 'already verified' not in check_response['result'].lower():
            # Log the flattened source code for debugging
            log_name = f'verify-{datetime.now().timestamp()}.log'
            with open(log_name, 'w') as log:
                log.write(code)
            print(f'Source code logged to {log_name}', file=sys.stderr)

            raise Exception('Verification failed')
        else:
            print('Contract is already verified')


def verify_contract(
    contract_name: str,
    contract_address: str,
    input_path: str,
    output_path: str,
    chain_id: str,
    api_key: str,
    constructor_args: str,
    library_address: str
) -> None:
    """
    Verify a contract on Etherscan.
    """
    print(f'\nVerifying {contract_name} at {contract_address}...')

    # Prepare verification data
    params, data, code = prepare_verification_data(
        contract_name, contract_address, input_path, output_path,
        chain_id, api_key, constructor_args, library_address
    )

    # Submit verification request
    verify_response = send_etherscan_api_request(params, data)

    # Handle "contract not yet deployed" case
    while 'locate' in verify_response.get('result', '').lower():
        print(verify_response['result'], file=sys.stderr)
        print('Waiting for 15 seconds for the network to update...', file=sys.stderr)
        time.sleep(15)
        verify_response = send_etherscan_api_request(params, data)

    # Check verification submission status
    if verify_response['status'] != '1' or verify_response['message'] != 'OK':
        if 'already verified' in verify_response['result'].lower():
            print('Contract is already verified')
            return
        raise Exception('Failed to submit verification request')

    # Get verification GUID
    guid = verify_response['result']
    print(f'Verification request submitted with GUID: {guid}')

    # Check verification status
    wait_for_verification(guid, params, api_key, code)

    # Get Etherscan URL
    subdomain = ETHERSCAN_SUBDOMAINS.get(chain_id, '')
    etherscan_url = f"https://{subdomain}etherscan.io/address/{contract_address}#code"
    print(f'Contract verified successfully at {etherscan_url}')


def get_action_address(spell_address: str) -> Optional[str]:
    """
    Get the action contract address from the spell contract.
    """
    try:
        result = subprocess.run(
            ['cast', 'call', spell_address, 'action()(address)'],
            capture_output=True,
            env=os.environ | {
                'ETH_GAS_PRICE': '0',
                'ETH_PRIO_FEE': '0'
            }
        )
        return result.stdout.decode('utf-8').strip()
    except Exception as e:
        print(f'Error getting action address: {str(e)}', file=sys.stderr)
        return None


def main():
    """
    Main entry point for the script.
    """
    try:
        # Get environment variables
        api_key = get_env_var(
            'ETHERSCAN_API_KEY',
            "You need an Etherscan API key to verify contracts.\n"
            "Create one at https://etherscan.io/myapikey\n"
            "Then export it with `export ETHERSCAN_API_KEY=xxxxxxxx'"
        )

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

        # Flatten source code
        flatten_source_code()

        # Verify spell contract
        verify_contract(
            contract_name=spell_name,
            contract_address=spell_address,
            input_path=SOURCE_FILE_PATH,
            output_path=f'out/DssSpell.sol/DssSpell.json',
            chain_id=chain_id,
            api_key=api_key,
            constructor_args=constructor_args,
            library_address=library_address
        )

        # Get and verify action contract
        action_address = get_action_address(spell_address)
        if not action_address:
            raise Exception('Could not determine action contract address')

        verify_contract(
            contract_name="DssSpellAction",
            contract_address=action_address,
            input_path=SOURCE_FILE_PATH,
            output_path=f'out/DssSpell.sol/DssSpellAction.json',
            chain_id=chain_id,
            api_key=api_key,
            constructor_args=constructor_args,
            library_address=library_address
        )

        print('\nVerification complete!')
    except Exception as e:
        print(f'\nError: {str(e)}', file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
