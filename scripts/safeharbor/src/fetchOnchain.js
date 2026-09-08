// Build internal representation from on-chain state
function normalize(details, chainDetails) {
    const validationWarnings = [];
    const onChainState = details.chains.reduce((chains, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];

        if (!chainName) {
            validationWarnings.push(
                `Unknown chain details in on-chain state: caip2ChainId='${chain.caip2ChainId}'.\nTo either remove or keep this chain, please add the chain details to the chain details tab in the Google Sheet.`,
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

    return { onChainState, validationWarnings };
}

export async function getNormalizedDataFromOnchainState(
    agreementContract,
    chainDetails,
) {
    const details = await agreementContract.getDetails();
    return normalize(details, chainDetails);
}
