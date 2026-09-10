import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

// The caller must validate state before planning updates.
export function planUpdates(
    agreementOnChainState,
    sheetState,
    sheetChainDetails,
) {
    assertUpdateInputs(agreementOnChainState, sheetState, sheetChainDetails);

    return [
        ...generateChainUpdates(
            agreementOnChainState,
            sheetState,
            sheetChainDetails,
        ),
        ...generateAccountUpdates(agreementOnChainState, sheetState),
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

function generateAccountUpdates(agreementOnChainState, sheetState) {
    // New chains are handled by generateChainUpdates.
    return Object.keys(agreementOnChainState)
        .filter((chainId) => Object.hasOwn(sheetState, chainId))
        .flatMap((chainId) =>
            generateChainAccountUpdates(
                chainId,
                agreementOnChainState[chainId].accounts,
                sheetState[chainId],
            ),
        );
}

function generateChainAccountUpdates(
    chainId,
    currentAccounts,
    desiredAccounts,
) {
    const updates = [];
    const { toAdd, toRemove } = calculateAccountDifferences(
        currentAccounts,
        desiredAccounts,
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
                removesAllCurrentAccounts ? [...toRemove].reverse() : toRemove,
            ],
        });
    }

    if (!removesAllCurrentAccounts && toAdd.length > 0) {
        updates.push({ fn: "addAccounts", args: [chainId, toAdd] });
    }

    return updates;
}

function generateChainUpdates(
    agreementOnChainState,
    sheetState,
    sheetChainDetails,
) {
    const updates = [];
    const { chainsToRemove, chainsToAdd } = calculateChainDifferences(
        agreementOnChainState,
        sheetState,
    );

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
                    assetRecoveryAddress:
                        sheetChainDetails.assetRecoveryAddress[
                            sheetChainDetails.name[chainId]
                        ],
                    accounts: sheetState[chainId],
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
        chainsToRemove: currentChainIds.filter(
            (chainId) => !desiredChainIds.includes(chainId),
        ),
        chainsToAdd: desiredChainIds.filter(
            (chainId) => !currentChainIds.includes(chainId),
        ),
    };
}

function assertUpdateInputs(
    agreementOnChainState,
    sheetState,
    sheetChainDetails,
) {
    const [diagnostic] = validateUpdateInputs(
        agreementOnChainState,
        sheetState,
        sheetChainDetails,
    );
    if (!diagnostic) {
        return;
    }
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}

function validateUpdateInputs(
    agreementOnChainState,
    sheetState,
    sheetChainDetails,
) {
    return Object.entries(sheetState).flatMap(([chainId, desiredAccounts]) => {
        const isNewChain = !Object.hasOwn(agreementOnChainState, chainId);
        const chainName = Object.hasOwn(sheetChainDetails.name, chainId)
            ? sheetChainDetails.name[chainId]
            : chainId;

        return validateChainUpdate(
            desiredAccounts ?? [],
            isNewChain,
            chainName,
        );
    });
}

function validateChainUpdate(accounts, isNewChain, chainName) {
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
    if (invalidAccounts.length === 0) {
        return [];
    }
    return [
        {
            code: $.INVALID_NEW_CHAIN_ACCOUNTS,
            context: { chainName, accounts: invalidAccounts },
        },
    ];
}
