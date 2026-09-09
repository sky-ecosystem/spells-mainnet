import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

export function normalizeOnChainState(details, chainDetails) {
    const validationWarnings = [];
    const onChainState = details.chains.reduce((chains, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];

        if (!chainName) {
            validationWarnings.push({
                code: $.UNKNOWN_ONCHAIN_CHAIN,
                context: { chainId: chain.caip2ChainId },
            });
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
