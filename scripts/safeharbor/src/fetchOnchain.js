// Build internal representation from on-chain state
function normalize(details, chainDetails) {
    return details.chains.reduce((groups, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];

        if (!chainName) {
            console.warn(
                `\n\n⚠️-----⚠️ \nUnknown chain details in on-chain state: caip2ChainId='${chain.caip2ChainId}'. \nTo either remove or keep this chain, please add the chain details to the chain details tab in the Google Sheet. \n⚠️-----⚠️\n\n`,
            );
            return groups;
        }

        groups[chainName] = chain.accounts.map((account) => ({
            accountAddress: account[0],
            childContractScope: account[1],
        }));
        return groups;
    }, {});
}

export async function getNormalizedDataFromOnchainState(
    agreementContract,
    chainDetails,
) {
    const details = await agreementContract.getDetails();
    return normalize(details, chainDetails);
}
