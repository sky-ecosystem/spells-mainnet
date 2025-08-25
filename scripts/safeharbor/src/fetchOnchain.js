import { getChainName } from "./utils/chainUtils.js";

// Build internal representation from on-chain state
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

export async function getNormalizedDataFromOnchainState(agreementContract) {
    const details = await agreementContract.getDetails()
    return normalize(details);
}
