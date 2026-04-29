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

./scripts/verification/verify.py DssSpell 0xYourSpellAddress
```

This verifies:
- The Spell contract you pass (e.g., `DssSpell`)
- The associated `DssSpellAction` via `action()` lookup

## Explorers
The script submits to explorers in this order, which matters — see Notes below:

1. Etherscan: used on mainnet when `ETHERSCAN_API_KEY` is set.
2. Sourcify: used on mainnet; no API key needed.

## Notes
- Libraries: if `DssExecLib` is configured in `foundry.toml`, it will be linked automatically by Foundry.
- Retries & delay: handled by `forge verify-contract` flags (`--retries`, `--delay`) per Foundry docs ([forge verify-contract](https://getfoundry.sh/forge/reference/verify-contract#forge-verify-contract)).
- **Explorer order is intentional.** Sourcify always submits Solidity Standard JSON Input, and Etherscan auto-imports verified sources from Sourcify within seconds. If Sourcify ran first, Forge's subsequent Etherscan submission would hit Etherscan's server-side "already verified" rejection and the stored source would stay as the Sourcify-shaped multi-file blob — and that state cannot be recovered client-side once it lands, only by redeploying. Running Etherscan first lets Forge's flattened submission land cleanly; Sourcify's later auto-import then can't overwrite the already-verified contract on Etherscan.
- **`--skip-is-verified-check` on the Etherscan call.** Forge's preflight `getabi` check sometimes returns false positives on stale CDN/network glitches. The flag bypasses that client-side check so the submission always goes through. Etherscan's server-side check is unconditional on its own, so this flag is belt-and-suspenders, not load-bearing.
- **Forge bug workaround**: When `ETHERSCAN_API_KEY` is set, Forge ignores `--verifier sourcify` and uses Etherscan ([foundry provider.rs](https://github.com/foundry-rs/foundry/blob/master/crates/verify/src/provider.rs#L170-L222)). This script unsets `ETHERSCAN_API_KEY` in the subprocess env when calling Sourcify so both Sourcify and Etherscan are used as intended. To verify the bug: run `ETHERSCAN_API_KEY=xxx forge verify-contract <addr> src/DssSpell.sol:DssSpell --verifier sourcify --flatten` and check Forge's output (it will target Etherscan, not Sourcify).

## Examples
```bash
# Mainnet spell, with Etherscan
ETHERSCAN_API_KEY=... ./scripts/verification/verify.py DssSpell 0xabc...def

# Custom retries/delay
VERIFY_RETRIES=10 VERIFY_DELAY=8 ./scripts/verification/verify.py DssSpell 0xabc...def
```
