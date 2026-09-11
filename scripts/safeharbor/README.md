# SafeHarbor

This script compares the approved Safeharbor Sheet with Sky's on-chain Agreement and generates the Solidity snippet needed to update its scope. It reads on-chain data but does not send transactions.

See the [SafeHarbor project](https://github.com/security-alliance/safe-harbor) and [registry contracts](https://github.com/security-alliance/safe-harbor/tree/0b0abb8b627eff87e2f7b52bf8ec484cd6ce0e32/registry-contracts/src) for background.

## Usage

Use Node.js 24. From `scripts/safeharbor`, install dependencies:

```bash
npm ci
```

Set `ETH_RPC_URL` to Ethereum mainnet or a compatible fork containing the mainnet Chainlog, its registered Agreement, and the Agreement's configured chain validator. The script uses the `SAFE_HARBOR_AGREEMENT` Chainlog entry; it does not accept an arbitrary Agreement address.

Choose an explicit command:

```bash
npm run --silent generate  # Generate the Solidity snippet for a spell
npm run --silent inspect   # Inspect source data, proposed changes, and warnings as JSON
npm run --silent verify    # Check that the Agreement matches the Sheet
```

From the repository root, `make safeharbor-generate`, `make safeharbor-inspect`, and `make safeharbor-verify` install dependencies and run the corresponding command.

### Results and exit codes

Resolve all warnings before using generated output. An empty changes list alone does not mean the Agreement matches: warnings can prevent changes from being calculated.

| Code | Meaning                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `0`  | Command completed. For `verify`, the Agreement matches with no warnings. For `inspect`, warnings may still be present in the report. |
| `1`  | Invalid input, configuration, network, or RPC error.                                                                                 |
| `2`  | `generate` is blocked by warnings, or `verify` found changes or warnings.                                                            |

Warnings go to stderr. `generate` prints Solidity only when changes are needed and there are no warnings. `inspect` prints JSON, not calldata or Solidity.

For scripting, use npm directly to preserve these exit codes; Make does not preserve distinct failure codes. Consume inspection output only after a successful command:

```bash
npm run --silent inspect > inspect.json && jq . inspect.json
```

## Design decisions

- **The approved Sheet is the desired state.** Review its contents as source data; matching the Sheet does not establish that its accounts belong in Sky's scope.
- **Warnings block generation.** Problems require review instead of producing a partial payload.
- **New chains must be accepted by the Agreement.** The script checks new chain IDs against its configured validator; rejected IDs block generation.
- **Account identifiers retain their exact spelling.** SafeHarbor supports non-EVM accounts, so account strings are case-sensitive. EVM recovery addresses are compared canonically; non-EVM recovery identifiers are compared exactly.
- **Recovery-address mismatches require a separate decision.** The script reports them rather than generating recovery-address changes.
- **An empty approved scope is valid.** A correctly formed Sheet with no active accounts can request chain removals.
- **Generator checks and execution checks serve different purposes.** The offline tests check script output; each spell still requires simulated execution and post-state verification.

## Reviewing a spell

1. Review and approve the Safeharbor Sheet change.
2. Run `generate` and confirm the calldata inserted in the spell matches its output.
3. Simulate the exact spell against the Agreement.
4. Point `ETH_RPC_URL` at the simulated post-state and run `verify`. Require exit `0`: no changes and no warnings.

## Initial Agreement setup

Initial setup is separate from the script. Deploy the Agreement through its public factory, configure its scope from the approved Sheet, transfer ownership to the PauseProxy, and adopt it through the registry in a governance spell.

Before adoption, independently verify factory provenance, PauseProxy ownership, and that the protocol name, agreement URI, contact details, and bounty terms match the Atlas. For the Agreement registered in Chainlog, also require clean `verify` output. The script does not check provenance, ownership, or adoption terms.

## Development checks

From `scripts/safeharbor`:

```bash
npm test -- --run
npm run lint
npm run format:check
```
