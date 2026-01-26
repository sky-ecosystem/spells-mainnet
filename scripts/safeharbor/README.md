# Overview

Safeharbor registry is a contract that allows protocols to identify addresses that are entitled to have funds recovered by a white hat during an attack.

- Read more about the SafeHarbor [here](https://github.com/security-alliance/safe-harbor)
- The full contracts for the registry can be found [here](https://github.com/security-alliance/safe-harbor/tree/main/registry-contracts/src/v2)

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
   - In a future spell, the pause proxy will call `safeharborRegistry.adoptSafeHarbor(agreementAddress)`
   - This officially accepts the terms and initiates the validity of SafeHarbor integration

## Validating the Agreement

There are a few steps to independently validate that a given agreement can be adopted by Sky protocol.

1. It has to be deployed via a transaction to known public factory.
2. The owner of the agreement has to be PauseProxy.
3. Agreement details (protocol name, agreement URI, contact details and bounty terms) has to match what's described in the Atlas.
4. The output of `make safeharbor-generate` command, on spells-mainnet repo, has to be "no updates".

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

To run the script, run the following command:

```bash
npm run generate
```

This will output a solidity snippet that contains the encoded calldatas calling the agreement contract to update it.

```bash
npm run inspect
```

Returns a JSON object containing the individual updates and the solidity snippet. 

In order to obtain machine-readable JSON output of the script, use the following command:

```bash
npm run --silent inspect > inspect.json
```

See the Solidity code to be used in the spell:

```bash
jq -r .solidityCode inspect.json
```
