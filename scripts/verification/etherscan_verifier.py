#!/usr/bin/env python3
"""
Etherscan block explorer verifier implementation.
"""
import sys
import json
import time
import requests
from datetime import datetime
from typing import Dict, Any

from .retry import retry_with_backoff

# Block explorer configurations
ETHERSCAN_API_URL = 'https://api.etherscan.io/v2/api'
ETHERSCAN_SUBDOMAINS = {
    '1': '',
    '11155111': 'sepolia.'
}
LICENSE_NUMBERS = {
    'GPL-3.0-or-later': 5,
    'AGPL-3.0-or-later': 13
}
SUPPORTED_CHAIN_IDS = ['1', '11155111']  # Mainnet and Sepolia


class EtherscanVerifier:
    """Etherscan block explorer verifier."""
    
    def __init__(self, api_key: str, chain_id: str):
        self.api_key = api_key
        self.chain_id = chain_id
        self.subdomain = ETHERSCAN_SUBDOMAINS.get(chain_id, '')
    
    def is_available(self) -> bool:
        """Check if Etherscan supports this chain."""
        return self.chain_id in SUPPORTED_CHAIN_IDS
    
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
        
        # Submit verification request (retry handled by decorator)
        try:
            verify_response = self._send_api_request(params, data)
        except Exception as e:
            print(f"Failed to submit verification request: {str(e)}", file=sys.stderr)
            return False
        
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
