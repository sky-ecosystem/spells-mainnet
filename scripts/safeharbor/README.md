# Overview

Safeharbor registry is a contract that allows protocols to identify addresses that are entitled to have funds recovered by a white hat during an attack.

# Initial Deployment

Before adoption, a single-time deploy and configuration needs to happen so Sky protocol can safely include changes to the scope within spells. The deployment will happen with the following steps:

1. **EOA AgreementV2 deployment**

   - Anyone can deploy an instance of the `AgreementV2` contract through its factory
   - Since the initial configuration is too big to safely fit within a spell execution, the first step will be done through an EOA

2. **Initial chain configuration**

   - The EOA will use the reference sheet to create the initial state of the scope
   - This includes adding all necessary chains and contracts, as well as the asset recovery addresses

3. **Ownership transfer to DSPause**

   - After the initial setup is done, the EOA will fully transfer the ownership of the `AgreementV2` contract to the PauseProxy
   - This enables the PauseProxy to modify the scope in the future

4. **Adoption**
   - On a future spell, the pause proxy will call `safeharborRegistry.adoptSafeHarbor(agreementAddress)`
   - This officially accepts the terms and initiates the validity of SafeHarbor integration

## Initial Deployment Verification

Since the initial deployment will be done through an EOA, the following steps need to be taken into consideration for spell crafters and reviewers to safely include the `adoptSafeHarbor` into a spell:

1. The `create` function was called through the verified AgreementV2Factory contract by SafeHarbor.
2. The owner of the `AgreementV2` contract is the PauseProxy.
3. The existing scope of the `AgreementV2` contract is the initial state of the scope of the sheet. This can be verified running the `generatePayload.js` script.

# General Flow of `generatePayload.js`

The script follows these steps:

1. Downloads latest CSV from Google Sheets and parses it locally

2. Builds internal representation of CSV data organized by chains/networks

3. Downloads current on-chain state from SafeHarbor registry

4. Builds comparable internal representation of on-chain state

5. Compares CSV vs on-chain state to identify differences

6. Outputs human-readable diff summary for Exec Sheet review:

   - Added accounts (with contract scope)
   - Removed accounts
   - Chain additions/removals

7. Generates encoded payload for executing the changes (if any).

# Running the script

To run the script, run the following command:
required env variables:
```
- RPC_URL: An endpoint to a node that has the registry and the agreement deployed.
```

```bash
npm run generate
```
This will create a `updates.json` file in the `scripts/safeharbor` directory.

# Testing

## Setting up the environment
required env variables:
```
- ETH_RPC_URL: An endpoint to a node that contains the registry and the agreement deployed.
```
For testing purposes, a public virtual testnet with a deployed and configured agreement is [here](https://dashboard.tenderly.co/dewiz-xyz/makerdao/testnet/07f7fbe4-ef01-46cf-a1f0-b8f5a8bf1afb)
