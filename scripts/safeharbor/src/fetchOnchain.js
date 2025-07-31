import {
    createProvider,
    createContractInstances,
} from "./utils/contractUtils.js";

import { getChainName } from "./utils/chainUtils.js";

async function fetchAgreementDetails() {
    const provider = createProvider();
    const { agreement } = createContractInstances(provider);
    return await agreement.getDetails();
}

// Build internal representation from on-chain state
function normalize(details) {
    return details.chains.reduce((groups, chain) => {
        const chainName = getChainName(chain.caip2ChainId);
        groups[chainName] = chain.accounts.map(account => ({
            accountAddress: account[0],
            childContractScope: account[1],
        }));
        return groups;
    }, {});
}

export async function getNormalizedDataFromOnchainState() {
    const details = await fetchAgreementDetails();
    return normalize(details);
}
