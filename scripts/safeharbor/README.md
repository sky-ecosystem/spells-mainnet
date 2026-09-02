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

1. Downloads latest CSV from Google Sheets and parses it locally

2. Builds internal representation of CSV data organized by chains/networks

3. Downloads current on-chain state from SafeHarbor registry

4. Builds comparable internal representation of on-chain state

5. Compares CSV vs on-chain state to identify differences

6. Generates encoded payload for executing the changes (if any).

7. Generates the solidity code for the updates.

# Running the script

Required env variables:

```
- ETH_RPC_URL: An endpoint to a node that has the registry and the agreement deployed.
```

Generate a Solidity snippet containing the encoded calls needed to update the agreement:

```bash
npm run generate
```

Inspect always outputs the complete result as JSON, including `updates`, `solidityCode`, and `validationWarnings`:

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

| Exit code | Meaning                                                                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `0`       | `generate` or `inspect` completed successfully regardless of reported differences, or `verify` found no differences or warnings. |
| `1`       | The command could not run because of invalid input, missing configuration, or another operational error.                         |
| `2`       | `verify` completed successfully but found updates or validation warnings.                                                        |

In order to obtain machine-readable JSON output of the script, use the following command:

```bash
npm run --silent inspect > inspect.json
```

See the Solidity code to be used in the spell:

```bash
jq -r .solidityCode inspect.json
```
