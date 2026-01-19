#!/usr/bin/env python3
"""
Verification package for Sky Protocol spells.
"""

from .contract_data import get_action_address, get_chain_id

__all__ = [
    "get_chain_id",
    "get_action_address",
]
