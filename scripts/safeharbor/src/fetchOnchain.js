import {
    createProvider,
    createContractInstances,
} from "./utils/contractUtils.js";

import { getChainName } from "./utils/chainUtils.js";

/**
 * Fetch on-chain agreement details.
 *
 * Creates a provider and contract instances, then returns the result of calling
 * `agreement.getDetails()` from the on-chain agreement contract. Any errors
 * encountered while connecting or fetching details propagate to the caller.
 *
 * @return {Promise<object>} Resolves to the raw agreement details object returned by the contract.
 */
async function fetchAgreementDetails() {
    const provider = createProvider();
    const { agreement } = createContractInstances(provider);
    return await agreement.getDetails();
}

/**
 * Convert on-chain agreement details into a normalized map keyed by chain name.
 *
 * Transforms `details.chains` into an object where each key is the human-readable
 * chain name (resolved via `getChainName`) and each value is an array of account
 * entries with `accountAddress` and `childContractScope`.
 *
 * @param {{ chains: Array<{ caip2ChainId: string, accounts: Array<[string, any]> }> }} details
 *   On-chain agreement details expected to contain a `chains` array. Each chain must have
 *   `caip2ChainId` and `accounts`, where each account is a two-element tuple:
 *   `[accountAddress, childContractScope]`.
 * @returns {{ [chainName: string]: Array<{ accountAddress: string, childContractScope: any }> }}
 *   A mapping from chain name to an array of normalized account objects.
 */
function normalize(details) {
    return details.chains.reduce((groups, chain) => {
        const chainName = getChainName(chain.caip2ChainId);
        groups[chainName] = chain.accounts.map((account) => ({
            accountAddress: account[0],
            childContractScope: account[1],
        }));
        return groups;
    }, {});
}

/**
 * Fetches agreement details from the on-chain contract and returns a normalized representation keyed by chain name.
 *
 * The returned object maps chain names to arrays of account entries:
 * {
 *   "<chainName>": [
 *     { accountAddress: "<address>", childContractScope: <scope> },
 *     ...
 *   ],
 *   ...
 * }
 *
 * Any errors raised while fetching on-chain data propagate to the caller.
 *
 * @return {Promise<Object>} A promise that resolves to the normalized mapping of chain names to arrays of account objects.
 */
export async function getNormalizedDataFromOnchainState() {
    const details = await fetchAgreementDetails();
    return normalize(details);
}
