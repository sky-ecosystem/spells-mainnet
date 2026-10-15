// Expects warning-free normalized Agreement and Sheet states from reconcile.
// It performs no validation and only calculates ordered Agreement changes.
export function planUpdates(agreementOnChainState, sheetState) {
    return [
        ...generateChainUpdates(agreementOnChainState, sheetState),
        ...generateAccountUpdates(agreementOnChainState, sheetState),
    ];
}

function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    const currentKeys = new Set(currentAccounts.map(getAccountKey));
    const desiredKeys = new Set(desiredAccounts.map(getAccountKey));

    const toRemove = currentAccounts
        .filter((acc) => !desiredKeys.has(getAccountKey(acc)))
        .map((acc) => acc.accountAddress);
    const toAdd = desiredAccounts.filter((acc) => !currentKeys.has(getAccountKey(acc)));

    return { toAdd, toRemove };
}

function getAccountKey(account) {
    return `${account.accountAddress}-${account.childContractScope}`;
}

function generateAccountUpdates(agreementOnChainState, sheetState) {
    // New chains are handled by generateChainUpdates.
    return Object.keys(agreementOnChainState)
        .filter((chainId) => sheetState[chainId])
        .flatMap((chainId) =>
            generateChainAccountUpdates(chainId, agreementOnChainState[chainId].accounts, sheetState[chainId].accounts),
        );
}

function generateChainAccountUpdates(chainId, currentAccounts, desiredAccounts) {
    const updates = [];
    const { toAdd, toRemove } = calculateAccountDifferences(currentAccounts, desiredAccounts);
    const removesAllCurrentAccounts = toRemove.length === currentAccounts.length;

    // Add replacements first if removing first would leave the chain empty.
    if (removesAllCurrentAccounts && toAdd.length > 0) {
        updates.push({ fn: "addAccounts", args: [chainId, toAdd] });
    }

    if (toRemove.length > 0) {
        // Reverse full replacements so swap-and-pop cannot remove a new scope.
        updates.push({
            fn: "removeAccounts",
            args: [chainId, removesAllCurrentAccounts ? [...toRemove].reverse() : toRemove],
        });
    }

    if (!removesAllCurrentAccounts && toAdd.length > 0) {
        updates.push({ fn: "addAccounts", args: [chainId, toAdd] });
    }

    return updates;
}

function generateChainUpdates(agreementOnChainState, sheetState) {
    const updates = [];
    const { chainsToRemove, chainsToAdd } = calculateChainDifferences(agreementOnChainState, sheetState);

    // Remove chains that are no longer in the Safeharbor Sheet - batch them together
    if (chainsToRemove.length > 0) {
        updates.push({
            fn: "removeChains",
            args: [chainsToRemove],
        });
    }

    // Add new chains from the Safeharbor Sheet - batch them together
    if (chainsToAdd.length > 0) {
        updates.push({
            fn: "addChains",
            args: [
                chainsToAdd.map((chainId) => ({
                    assetRecoveryAddress: sheetState[chainId].assetRecoveryAddress,
                    accounts: sheetState[chainId].accounts,
                    caip2ChainId: chainId,
                })),
            ],
        });
    }

    return updates;
}

function calculateChainDifferences(agreementOnChainState, sheetState) {
    const currentChainIds = Object.keys(agreementOnChainState);
    const desiredChainIds = Object.keys(sheetState);
    return {
        chainsToRemove: currentChainIds.filter((chainId) => !desiredChainIds.includes(chainId)),
        chainsToAdd: desiredChainIds.filter((chainId) => !currentChainIds.includes(chainId)),
    };
}
