#!/usr/bin/env python3
"""
Sourcify block explorer verifier implementation.
"""
import sys
import json
import requests
from typing import Dict, Any

from .retry import retry_with_backoff


# Block explorer configurations
SOURCIFY_API_URL = 'https://sourcify.dev/server'
SUPPORTED_CHAIN_IDS = ['1', '11155111']  # Mainnet and Sepolia


class SourcifyVerifier:
    """Sourcify block explorer verifier."""
    
    def __init__(self, chain_id: str):
        self.chain_id = chain_id
    
    def is_available(self) -> bool:
        """Check if Sourcify supports this chain."""
        return self.chain_id in SUPPORTED_CHAIN_IDS
    
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
            print(f"Failed to verify on Sourcify: {str(e)}", file=sys.stderr)
            return False
