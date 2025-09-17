import { getChainName } from "./utils/chainUtils.js";

/**
 * Convert on-chain agreement details into an internal, chain-keyed account map.
 *
 * Takes a `details` object with a `chains` array and returns an object keyed by
 * chain name (resolved from each chain's CAIP-2 ID) where each value is an
 * array of account entries with `accountAddress` and `childContractScope`.
 *
 * @param {Object} details - On-chain details object.
 * @param {Array<Object>} details.chains - Array of chain records from the contract.
 * @param {string} details.chains[].caip2ChainId - CAIP-2 chain identifier used to derive the chain name.
 * @param {Array<Array<string>>} details.chains[].accounts - Array of 2-element account tuples: [address, childContractScope].
 * @return {Object<string, Array<{accountAddress: string, childContractScope: string}>>} Normalized mapping: chainName -> array of account objects.
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
 * Retrieve on-chain agreement details and return a normalized representation.
 *
 * Calls the contract's `getDetails()` and converts the on-chain structure into an object
 * keyed by chain name; each value is an array of objects with `accountAddress` and
 * `childContractScope`.
 *
 * Any errors thrown by the contract call propagate to the caller.
 *
 * @returns {Promise<Object>} Normalized on-chain data keyed by chain name.
 */
export async function getNormalizedDataFromOnchainState(agreementContract) {
    const details = await agreementContract.getDetails();
    return normalize(details);
}
