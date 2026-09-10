import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function normalizeOnChainState(details, chainDetails) {
    const { value, warnings } = details.chains.reduce(
        ({ value, warnings }, chain) => {
            if (!Object.hasOwn(chainDetails.name, chain.caip2ChainId)) {
                warnings.push({
                    code: $.UNKNOWN_ONCHAIN_CHAIN,
                    context: { chainId: chain.caip2ChainId },
                });
                return { value, warnings };
            }

            return {
                value: {
                    ...value,
                    [chainDetails.name[chain.caip2ChainId]]: {
                        accounts: chain.accounts.map((account) => ({
                            accountAddress: account[0],
                            childContractScope: account[1],
                        })),
                        assetRecoveryAddress: chain.assetRecoveryAddress,
                    },
                },
                warnings,
            };
        },
        { value: {}, warnings: [] },
    );

    return { value, warnings: [...warnings, ...validateUniqueAccounts(value)] };
}

function validateUniqueAccounts(onChainState) {
    return Object.entries(onChainState).flatMap(([chainName, { accounts }]) => {
        const addresses = accounts.map(({ accountAddress }) => accountAddress);
        return [...findDuplicateIndexes(addresses)].map((index) => ({
            code: $.DUPLICATE_ONCHAIN_ACCOUNT,
            context: {
                chainName,
                address: addresses[index],
                firstScope:
                    accounts[addresses.indexOf(addresses[index])]
                        .childContractScope,
                duplicateScope: accounts[index].childContractScope,
            },
        }));
    });
}
