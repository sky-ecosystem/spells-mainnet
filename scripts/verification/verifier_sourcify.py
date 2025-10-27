#!/usr/bin/env python3
"""
Sourcify block explorer verifier implementation using forge verify-contract.
"""
import sys
import subprocess

from .retry import retry_with_backoff

# Block explorer configurations
CHAIN_ID = '1'  # Mainnet only

class VerifierSourcify:
    """Sourcify block explorer verifier using forge verify-contract."""
    
    def __init__(self, chain_id: str):
        self.chain_id = chain_id
    
    def is_available(self) -> bool:
        """Check if Sourcify supports this chain."""
        return self.chain_id == CHAIN_ID
    
    def get_verification_url(self, contract_address: str) -> str:
        """Get Sourcify URL for the verified contract."""
        return f"https://sourcify.dev/#/lookup/{contract_address}"
    
    @retry_with_backoff(max_retries=3, base_delay=2, max_delay=30)
    def verify_contract(
        self,
        contract_name: str,
        contract_address: str,
        constructor_args: str,
        library_address: str = ""
    ) -> bool:
        """Verify contract on Sourcify using forge verify-contract."""
        print(f'\nVerifying {contract_name} at {contract_address} on Sourcify...')
        
        # Build forge verify-contract command
        cmd = [
            'forge', 'verify-contract',
            contract_address,
            f'src/DssSpell.sol:{contract_name}',
            '--verifier', 'sourcify',
            '--flatten',
            '--watch'
        ]
        
        # Add constructor arguments if provided
        if constructor_args:
            cmd.extend(['--constructor-args', constructor_args])
        
        # Add library linking if provided
        if library_address:
            cmd.extend(['--libraries', f'src/DssExecLib.sol:DssExecLib:{library_address}'])
        
        try:
            subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
            )
            
            print(f'✓ Contract verified successfully at {self.get_verification_url(contract_address)}')
            return True
            
        except subprocess.CalledProcessError as e:
            # Check if it's already verified
            if 'already verified' in e.stderr.lower() or 'already verified' in e.stdout.lower():
                print('✓ Contract is already verified on Sourcify')
                return True
            
            print(f"✗ Verification failed: {e.stderr}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"✗ Unexpected error during verification: {str(e)}", file=sys.stderr)
            return False
