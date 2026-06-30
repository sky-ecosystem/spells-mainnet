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
- **Explorer order is intentional.** Sourcify itself submits to Etherscan as part of its verification flow ([Sourcify `EtherscanVerifyApiService`](https://github.com/argotorg/sourcify/blob/master/services/server/src/server/services/storageServices/EtherscanVerifyApiService.ts)), so if Sourcify ran first, Forge's subsequent Etherscan call would be rejected as "already verified" and the stored source on Etherscan would be whatever Sourcify pushed (no client-side recovery once that lands — only redeploying with different bytecode fixes it). Running Etherscan first lets Forge's flattened submission land cleanly; Sourcify's later push gets rejected on the Etherscan side but Sourcify-side verification still succeeds.
- **`--skip-is-verified-check` on the Etherscan call.** Defensive: tells Forge to skip its client-side preflight `getabi` check and always submit. Not load-bearing — Etherscan's server-side rejection is the unconditional one — but harmless and keeps the script behavior independent of any preflight quirks.
- **Forge bug workaround**: When `ETHERSCAN_API_KEY` is set, Forge ignores `--verifier sourcify` and uses Etherscan ([foundry provider.rs](https://github.com/foundry-rs/foundry/blob/master/crates/verify/src/provider.rs#L170-L222)). This script unsets `ETHERSCAN_API_KEY` in the subprocess env when calling Sourcify so both Sourcify and Etherscan are used as intended. To verify the bug: run `ETHERSCAN_API_KEY=xxx forge verify-contract <addr> src/DssSpell.sol:DssSpell --verifier sourcify --flatten` and check Forge's output (it will target Etherscan, not Sourcify).

## Examples
```bash
# Mainnet spell, with Etherscan
ETHERSCAN_API_KEY=... ./scripts/verification/verify.py DssSpell 0xabc...def

# Custom retries/delay
VERIFY_RETRIES=10 VERIFY_DELAY=8 ./scripts/verification/verify.py DssSpell 0xabc...def
```
