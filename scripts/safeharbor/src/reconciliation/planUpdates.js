import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

// The caller must validate state before planning updates.
export function planUpdates(onChainState, sheetState, chainDetails) {
    const [diagnostic] = validateUpdateInputs(onChainState, sheetState);
    if (diagnostic) {
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }

    return [
        ...generateChainUpdates(onChainState, sheetState, chainDetails),
        ...generateAccountUpdates(onChainState, sheetState, chainDetails),
    ];
}

function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    const currentKeys = new Set(currentAccounts.map(getAccountKey));
    const desiredKeys = new Set(desiredAccounts.map(getAccountKey));

    const toRemove = currentAccounts
        .filter((acc) => !desiredKeys.has(getAccountKey(acc)))
        .map((acc) => acc.accountAddress);
    const toAdd = desiredAccounts.filter(
        (acc) => !currentKeys.has(getAccountKey(acc)),
    );

    return { toAdd, toRemove };
}

function getAccountKey(account) {
    return `${account.accountAddress}-${account.childContractScope}`;
}

function generateAccountUpdates(onChainState, sheetState, chainDetails) {
    const updates = [];

    // New chains are handled by generateChainUpdates
    for (const chainName of Object.keys(onChainState)) {
        if (!Object.hasOwn(sheetState, chainName)) {
            continue;
        }

        const chainId = chainDetails.caip2ChainId[chainName];
        const currentAccounts = onChainState[chainName].accounts;

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts,
            sheetState[chainName],
        );

        const removesAllCurrentAccounts =
            toRemove.length === currentAccounts.length;

        // Add replacements first if removing first would leave the chain empty.
        if (removesAllCurrentAccounts && toAdd.length > 0) {
            updates.push({ fn: "addAccounts", args: [chainId, toAdd] });
        }

        if (toRemove.length > 0) {
            // Reverse full replacements so swap-and-pop cannot remove a new scope.
            updates.push({
                fn: "removeAccounts",
                args: [
                    chainId,
                    removesAllCurrentAccounts
                        ? [...toRemove].reverse()
                        : toRemove,
                ],
            });
        }

        if (!removesAllCurrentAccounts && toAdd.length > 0) {
            updates.push({ fn: "addAccounts", args: [chainId, toAdd] });
        }
    }

    return updates;
}

function generateChainUpdates(onChainState, sheetState, chainDetails) {
    const updates = [];

    const currentChainNames = Object.keys(onChainState);
    const desiredChainNames = Object.keys(sheetState);

    const chainsToRemove = currentChainNames.filter(
        (chain) => !desiredChainNames.includes(chain),
    );
    const chainsToAdd = desiredChainNames.filter(
        (chain) => !currentChainNames.includes(chain),
    );

    // Remove chains that are no longer in the Safeharbor Sheet - batch them together
    if (chainsToRemove.length > 0) {
        const chainIdsToRemove = chainsToRemove.map(
            (chainName) => chainDetails.caip2ChainId[chainName],
        );
        updates.push({ fn: "removeChains", args: [chainIdsToRemove] });
    }

    // Add new chains from the Safeharbor Sheet - batch them together
    if (chainsToAdd.length > 0) {
        updates.push({
            fn: "addChains",
            args: [
                chainsToAdd.map((chainName) => ({
                    assetRecoveryAddress:
                        chainDetails.assetRecoveryAddress[chainName],
                    accounts: sheetState[chainName],
                    caip2ChainId: chainDetails.caip2ChainId[chainName],
                })),
            ],
        });
    }

    return updates;
}

function validateUpdateInputs(onChainState, sheetState) {
    return Object.entries(sheetState).flatMap(
        ([chainName, desiredAccounts]) => {
            const isNewChain = !Object.hasOwn(onChainState, chainName);
            const accounts = desiredAccounts || [];
            if (accounts.length === 0) {
                return [
                    {
                        code: isNewChain
                            ? $.ADDED_CHAIN_WITHOUT_ACCOUNTS
                            : $.EXISTING_CHAIN_WITHOUT_ACCOUNTS,
                        context: { chainName },
                    },
                ];
            }
            if (!isNewChain) {
                return [];
            }

            const invalidAccounts = accounts.filter(
                (account) =>
                    !account.accountAddress ||
                    account.childContractScope === undefined ||
                    account.childContractScope === null,
            );
            return invalidAccounts.length > 0
                ? [
                      {
                          code: $.INVALID_NEW_CHAIN_ACCOUNTS,
                          context: { chainName, accounts: invalidAccounts },
                      },
                  ]
                : [];
        },
    );
}
