# Contract Verification

Minimal verification wrapper that shells out to `forge verify-contract` per explorer, using Foundry's built-in retries and delays.

## Usage

```bash
# from repo root
export ETH_RPC_URL="https://..."
# optional for Etherscan
export ETHERSCAN_API_KEY="..."

# optional overrides (defaults: 5)
export VERIFY_RETRIES=5
export VERIFY_DELAY=5

python -m scripts.verification.verify DssSpell 0xYourSpellAddress
```

This verifies:
- The Spell contract you pass (e.g., `DssSpell`)
- The associated `DssSpellAction` via `action()` lookup

## Explorers
- Sourcify: used on mainnet; no API key needed
- Etherscan: used on mainnet when `ETHERSCAN_API_KEY` is set

## Notes
- Libraries: if `DssExecLib` is configured in `foundry.toml`, it is linked automatically via `--libraries`.
- Retries & delay: handled by `forge verify-contract` flags (`--retries`, `--delay`) per Foundry docs ([forge verify-contract](https://getfoundry.sh/forge/reference/verify-contract#forge-verify-contract)).

## Examples
```bash
# Mainnet spell, with Etherscan
ETHERSCAN_API_KEY=... python -m scripts.verification.verify DssSpell 0xabc...def

# Custom retries/delay
VERIFY_RETRIES=10 VERIFY_DELAY=8 python -m scripts.verification.verify DssSpell 0xabc...def
```
