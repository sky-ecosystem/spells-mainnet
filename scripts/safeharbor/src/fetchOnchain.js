// Build internal representation from on-chain state
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

export async function getNormalizedDataFromOnchainState(
    agreementContract,
    chainDetails,
) {
    const details = await agreementContract.getDetails();
    return normalize(details, chainDetails);
}
