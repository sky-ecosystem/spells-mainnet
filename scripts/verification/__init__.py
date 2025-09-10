#!/usr/bin/env python3
"""
Verification package for Sky Protocol spells.
"""

from .etherscan_verifier import EtherscanVerifier
from .sourcify_verifier import SourcifyVerifier
from .contract_data import (
    get_chain_id,
    get_library_address,
    flatten_source_code,
    get_contract_metadata,
    read_flattened_code,
    get_action_address
)

__all__ = [
    'EtherscanVerifier', 
    'SourcifyVerifier',
    'get_chain_id',
    'get_library_address',
    'flatten_source_code',
    'get_contract_metadata',
    'read_flattened_code',
    'get_action_address'
]
