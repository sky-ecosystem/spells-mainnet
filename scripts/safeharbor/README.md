# Overview

Safeharbor registry is a contract that allows protocols to identify addresses that are entitled to have funds recovered by a white hat during an attack.

- Read more about the SafeHarbor [here](https://github.com/security-alliance/safe-harbor)
- The full contracts for the registry can be found [here](https://github.com/security-alliance/safe-harbor/tree/0b0abb8b627eff87e2f7b52bf8ec484cd6ce0e32/registry-contracts/src)

# Initial Deployment

Before adoption, a single-time deploy and configuration needs to happen so Sky protocol can safely include changes to the scope within spells. The deployment will happen with the following steps:

1. **EOA Agreement deployment**

   - Anyone can deploy an instance of the `Agreement` contract through its factory
   - Since the initial configuration is too big to safely fit within a spell execution, the first step will be done through an EOA

2. **Initial chain configuration**

   - The EOA will use the reference sheet to create the initial state of the scope
   - This includes adding all necessary chains and contracts, as well as the asset recovery addresses

3. **Ownership transfer to DSPause**

   - After the initial setup is done, the EOA will fully transfer the ownership of the `Agreement` contract to the PauseProxy
   - This enables the PauseProxy to modify the scope in the future

4. **Adoption**
   - In a future spell, the pause proxy will call `safeharborRegistry.adoptSafeHarbor(agreementAddress)`
   - This officially accepts the terms and initiates the validity of SafeHarbor integration

## Validating the Agreement

There are a few steps to independently validate that a given agreement can be adopted by Sky protocol.

1. It has to be deployed via a transaction to known public factory.
2. The owner of the agreement has to be PauseProxy.
3. Agreement details (protocol name, agreement URI, contact details and bounty terms) has to match what's described in the Atlas.
4. `npm run verify`, from `scripts/safeharbor`, has to exit with code `0`.

If all of these steps are done, the agreement can be adopted by Sky protocol.

# General Flow of `generatePayload.js`

The script follows these steps:

1. Downloads the Safeharbor Sheet as CSV and parses it locally

2. Validates CSV headers before building the internal representation organized by chains/networks

3. Downloads current on-chain state from the SafeHarbor Agreement

4. Builds comparable internal representation of on-chain state

5. Collects warnings from Safeharbor Sheet and on-chain normalization, then validates the comparable states. Any warning stops generation before diffing or encoding, returning `updates: []`, `solidityCode: ""`, and the collected `validationWarnings`.

6. If there are no warnings, compares Safeharbor Sheet and on-chain state and encodes the required updates (if any).

7. Generates the solidity code for the updates.

`index.js` validates the command and RPC configuration, creates the provider, and wires the Agreement reader, payload generator, and command runner through creator closures. It destroys the provider when the command finishes. `agreement.js` uses the injected provider to resolve the Agreement address through `chainlog.js`, construct the Agreement instance, and fetch its details. Its pure `normalizeOnchainState` function converts those details into reconciliation state without network access. `sheet.js` reads and normalizes the Safeharbor Sheet; CSV is its transport format. The RPC URL stays at the entrypoint; the Agreement instance stays inside the reader.

Validation returns plain diagnostics with a stable `code` and optional `context` containing raw facts. For example:

```json
{
  "code": "UNKNOWN_SHEET_CHAIN",
  "context": { "chainName": "BASE" }
}
```

Diagnostics contain no human-readable messages. `formatDiagnostic.js` owns their wording; the CLI prints each diagnostic to stderr once. `generate` and `verify` also print their command summaries; `inspect` prints JSON instead. The generator, CSV adapter, validators, and diff logic do not print progress or errors. Fatal application checks propagate native `Error` objects carrying a `diagnostic`; parser, fetch, and RPC exceptions propagate unchanged and are reported once at the CLI boundary. Command and header checks still exit `1`, while reconciliation warnings retain their command-specific exit behavior.

The `validationWarnings` field is retained, but its entries are now diagnostic objects rather than strings. This also changes the `inspect` JSON contract: consumers should use `code` and `context`, not parse warning text. `inspect` continues to print human-readable diagnostics to stderr, keeping stdout reserved for JSON.

The contracts tab in the Safeharbor Sheet is exported as CSV and requires `Status`, `Chain`, `Address`, and either `isFactory` or `IsFactory`. Chain metadata requires `Name`, `Chain Id`, and `Asset Recovery Address`. Missing headers, including in header-only files, and malformed CSV cause an error before normalization or update generation; CLI commands exit with code `1`. Completely empty files are invalid because they have no headers. A contracts CSV with valid headers and no `ACTIVE` records is a legitimate empty desired state and may generate chain removals when the corresponding chain metadata is available.

Nonblank chain metadata rows must contain all three required fields; incomplete rows produce warnings listing the missing fields, even if those chains are not in the desired state. Completely blank rows are ignored. A row with only an extra column populated is incomplete, not blank.

EVM recovery addresses for desired chains, including newly added chains, are validated with ethers `getAddress`; malformed addresses and invalid mixed-case checksums produce warnings, while valid lowercase addresses are accepted. For chains present in both states, missing on-chain recovery addresses produce warnings, and EVM recovery addresses are compared in canonical checksummed form. Only chains absent from the on-chain state skip comparison. Solana and other non-EVM recovery identifiers are compared exactly, including case; no chain-specific syntax validation is performed for them. Recovery mismatches produce warnings, not recovery-address updates. An empty `updates` array alone does not establish a successful reconciliation: `validationWarnings` must also be empty.

Duplicate chain names or IDs in complete metadata rows produce warnings without overwriting earlier mappings. Repeated account addresses within a chain in either desired or current state also produce warnings, including when their scopes differ. These checks run before diffing and block all executable output. Account addresses retain the Agreement's exact, case-sensitive string semantics; the same address may legitimately appear on different chains. Canonical EVM comparison applies only to recovery addresses, not account identifiers.

Full account replacements add before removing because the Agreement rejects removing every account from a chain. Old accounts are then removed in reverse current-state order: the Agreement removes the first matching address and uses swap-and-pop, so forward removal can accidentally delete a newly added scope replacement. Partial replacements continue to remove before adding. Reordering equivalent accounts alone produces no updates.

# Running the script

Required env variables:

```
- ETH_RPC_URL: An endpoint to a node that has the registry and the agreement deployed.
```

A command is required: `generate`, `inspect`, or `verify`. There is no default command.

Generate a Solidity snippet containing the encoded calls needed to update the agreement:

```bash
npm run generate
```

If any validation warning is reported, `generate` exits with code `2` and prints neither Solidity nor a success message.

On successful inspection, `inspect` outputs the result as JSON, including `updates`, `solidityCode`, and `validationWarnings`, and exits with code `0` even when warnings are present. With warnings, the result is diagnostic only: updates and Solidity are empty. Parsing, network, RPC, configuration, and command errors instead exit with code `1` without a JSON result:

```bash
npm run inspect
```

Verify that the sheet and the on-chain agreement match:

```bash
npm run verify
```

`verify` succeeds only when there are no updates and no validation warnings.

From the repository root, `make safeharbor-verify` provides the same verification as a convenience command. Use `npm run verify` directly when the distinct non-zero exit codes are required.

All commands use the following exit codes:

| Exit code | Meaning                                                                                                                                           |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`       | `generate` completed without warnings; `inspect` completed, including diagnostic results with warnings; or `verify` found no updates or warnings. |
| `1`       | The command could not run because of invalid input, missing configuration, or another operational error.                                          |
| `2`       | `generate` was blocked by validation warnings, or `verify` found updates or validation warnings.                                                  |

In order to obtain machine-readable JSON output of the script, use the following command:

```bash
npm run --silent inspect > inspect.json
```

After checking that `validationWarnings` is empty, see the Solidity code to be reviewed for use in the spell:

```bash
jq -r .solidityCode inspect.json
```

# Testing and review

From `scripts/safeharbor`, install dependencies, then run the offline suite and checks:

```bash
npm ci
npm test -- --run
npm run lint
npm run format:check
```

The tests cover the following scenarios; this is not a claim of completeness:

- `generatePayload.test.js` uses explicit CSV and Agreement-state fixtures with real parsing, normalization, validation, diffing, encoding, and Solidity rendering. It asserts structured diagnostics and no console output from the pipeline. It covers chain/account additions and removals, mixed updates, empty states, warnings, duplicate data, recovery metadata, and scope changes. Replacement fixtures include `[A] → [B,C]`, `[A,B,C] → [D]`, partial `[A,B,C] → [A,C,D]`, reordered equivalents, sole-account scope changes, and simultaneous two- and three-account scope changes.
- Every update produced in those pipeline tests is decoded with the Agreement ABI; its function and all normalized arguments must equal the corresponding update. Selected scenarios also retain raw calldata and readable decoded snapshots. These ethers encoding/decoding checks establish consistency, not independent EVM verification.
- `cli.test.js` exercises all three command handlers through the real pipeline, mocking only CSV fetching and injecting an Agreement-details reader stub. It checks exact output and returned exit codes for clean reconciliation, valid chain removal, warnings with and without account differences, multiple simultaneous warnings, missing headers, malformed CSV, and fetch failures. It verifies that individual diagnostics and failures are reported once and `inspect` JSON retains structured diagnostics. These are in-process integration tests, not subprocess or live-RPC tests.
- `index.integration.test.js` exercises the entrypoint with CSV fetching and ethers construction mocked. It checks missing/unknown commands and missing RPC configuration before dependencies are constructed, real closure wiring, provider cleanup after success and pipeline failure, and provider construction errors.
- `agreement.integration.test.js` checks Agreement construction and state reads, including propagation of lookup, construction, and read errors, with Chainlog lookup and contract construction mocked. `chainlog.integration.test.js` uses real ethers with a mocked RPC call to check the lookup target, calldata, and returned address.
- `src/agreement.test.js` contains pure unit tests for empty state, unknown-chain warnings, chain/account ordering, exact address strings, bigint scopes, and input nonmutation.
- Colocated `src/validateOptions.test.js` and `src/sheet.test.js` check pure command and header diagnostic results; `src/formatDiagnostic.test.js` checks human-readable wording independently of detection.
- Separate tests cover required headers and factory aliases, incomplete metadata, duplicates, EVM checksum validation, exact non-EVM comparisons, the Solidity wrapper, and defensive rejection of empty account arrays that CSV normalization cannot produce. A multi-chain defensive fixture verifies that invalid accounts in a later new chain prevent all encoding, including removals for earlier chains. CSV adapter tests cover HTTP failures, invalid or missing content types, and unchanged propagation of fetch failures without console output.

The seven replacement/reordering fixtures were also executed against the actual Agreement at `0xf17bB418B4EC251f300Aa3517Cb37349f17697A1` on a local Ethereum fork at block **25934096**, hash `0xa29f7a0e3eaed16874bd16a0936bf2f973260008fe39be32c56097d084a8beb4`. Before the ordering fix, the simultaneous scope-change fixtures retained an old scope. With reverse removals, all seven reached the expected account scopes and reconciled with no updates or validation warnings. This was a local-fork check for this change, not a CI RPC dependency or a live transaction.

For each spell, the approved spreadsheet remains the desired-state source of truth. Review its changes, match the generated calldata to the calldata inserted in the spell, execute the spell in a Tenderly Virtual TestNet, and run `verify` against that simulated post-state. Both updates and validation warnings must be empty. The offline suite and the pinned replacement regression do not replace these payload-specific controls.
