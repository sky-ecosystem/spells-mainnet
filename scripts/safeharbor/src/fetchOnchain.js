/**
 * @typedef {Object} SafeHarborAccount
 * @property {string} accountAddress
 * @property {number} childContractScope
 */

/**
 * @typedef {Object} SafeHarborChainState
 * @property {SafeHarborAccount[]} accounts
 * @property {string} assetRecoveryAddress
 */

/**
 * @typedef {Object} ChainDetails
 * @property {Record<string, string>} caip2ChainId
 * @property {Record<string, string>} assetRecoveryAddress
 * @property {Record<string, string>} name
 */

/**
 * Normalizes the raw `agreement.getDetails()` response into the chain-keyed
 * structure used by the payload generator.
 *
 * Chains that are present on-chain but missing from the chain details sheet are
 * skipped with a warning so they can be reconciled manually.
 *
 * @param {{ chains: Array<{
 *   caip2ChainId: string,
 *   assetRecoveryAddress: string,
 *   accounts: Array<[string, number]>,
 * }> }} details
 * @param {ChainDetails} chainDetails
 * @returns {Record<string, SafeHarborChainState>}
 */
function normalize(details, chainDetails) {
    return details.chains.reduce((chains, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];

        if (!chainName) {
            console.warn(
                `\n\n⚠️-----⚠️ \nUnknown chain details in on-chain state: caip2ChainId='${chain.caip2ChainId}'. \nTo either remove or keep this chain, please add the chain details to the chain details tab in the Google Sheet. \n⚠️-----⚠️\n\n`,
            );
            return chains;
        }

        chains[chainName] = {
            accounts: chain.accounts.map((account) => ({
                accountAddress: account[0],
                childContractScope: account[1],
            })),
            assetRecoveryAddress: chain.assetRecoveryAddress,
        };
        return chains;
    }, {});
}

/**
 * Fetches the current SafeHarbor agreement state from-chain and normalizes it
 * into the chain-keyed representation consumed by update generation.
 *
 * @param {{ getDetails: () => Promise<{ chains: Array<{
 *   caip2ChainId: string,
 *   assetRecoveryAddress: string,
 *   accounts: Array<[string, number]>,
 * }> }> }} agreementContract
 * @param {ChainDetails} chainDetails
 * @returns {Promise<Record<string, SafeHarborChainState>>}
 */
export async function getNormalizedDataFromOnchainState(
    agreementContract,
    chainDetails,
) {
    const details = await agreementContract.getDetails();
    return normalize(details, chainDetails);
}
