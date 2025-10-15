#!/usr/bin/env python3
"""
Etherscan block explorer verifier implementation using forge verify-contract.
"""
import os
import sys
import subprocess

from .retry import retry_with_backoff

# Block explorer configurations
ETHERSCAN_SUBDOMAINS = {
    '1': '',
    '11155111': 'sepolia.'
}
SUPPORTED_CHAIN_IDS = ['1', '11155111']  # Mainnet and Sepolia


class EtherscanVerifier:
    """Etherscan block explorer verifier using forge verify-contract."""
    
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
    def verify_contract(
        self,
        contract_name: str,
        contract_address: str,
        constructor_args: str,
        library_address: str = ""
    ) -> bool:
        """Verify contract on Etherscan using forge verify-contract."""
        print(f'\nVerifying {contract_name} at {contract_address} on Etherscan...')
        
        # Build forge verify-contract command
        cmd = [
            'forge', 'verify-contract',
            contract_address,
            f'src/{contract_name}.sol:{contract_name}',
            '--verifier', 'etherscan',
            '--etherscan-api-key', self.api_key,
            '--flatten',
            '--watch'
        ]
        
        # Add constructor arguments if provided
        if constructor_args:
            cmd.extend(['--constructor-args', constructor_args])
        
        # Add library linking if provided
        if library_address:
            cmd.extend(['--libraries', f'src/DssExecLib.sol:DssExecLib:{library_address}'])
        
        # Set environment variables for the subprocess
        env = os.environ.copy()
        env['ETH_RPC_URL'] = os.environ.get('ETH_RPC_URL', '')
        
        try:
            subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
                env=env
            )
            
            print(f'Contract verified successfully at {self.get_verification_url(contract_address)}')
            return True
            
        except subprocess.CalledProcessError as e:
            # Check if it's already verified
            if 'already verified' in e.stderr.lower() or 'already verified' in e.stdout.lower():
                print('Contract is already verified on Etherscan')
                return True
            
            print(f"Verification failed: {e.stderr}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Unexpected error during verification: {str(e)}", file=sys.stderr)
            return False
