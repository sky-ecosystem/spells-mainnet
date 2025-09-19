
// Build internal representation from on-chain state
function normalize(details, chainDetails) {
    return details.chains.reduce((groups, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];
        groups[chainName] = chain.accounts.map((account) => ({
            accountAddress: account[0],
            childContractScope: account[1],
        }));
        return groups;
    }, {});
}

export async function getNormalizedDataFromOnchainState(agreementContract, chainDetails) {
    const details = await agreementContract.getDetails();
    return normalize(details, chainDetails);
}
