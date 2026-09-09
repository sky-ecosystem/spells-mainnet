import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

export function normalizeOnChainState(details, chainDetails) {
    return details.chains.reduce(
        ({ value, warnings }, chain) => {
            const chainName = chainDetails.name[chain.caip2ChainId];

            if (!chainName) {
                warnings.push({
                    code: $.UNKNOWN_ONCHAIN_CHAIN,
                    context: { chainId: chain.caip2ChainId },
                });
                return { value, warnings };
            }

            return {
                value: Object.assign(value, {
                    [chainName]: {
                        accounts: chain.accounts.map((account) => ({
                            accountAddress: account[0],
                            childContractScope: account[1],
                        })),
                        assetRecoveryAddress: chain.assetRecoveryAddress,
                    },
                }),
                warnings,
            };
        },
        { value: {}, warnings: [] },
    );
}
