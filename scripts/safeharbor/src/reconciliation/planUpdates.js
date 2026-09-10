import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";

// The caller must validate state before planning updates.
export function planUpdates(agreementOnChainState, sheetState) {
    assertUpdateInputs(agreementOnChainState, sheetState);

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
        .filter((chainId) => sheetState[chainId])
        .flatMap((chainId) =>
            generateChainAccountUpdates(
                chainId,
                agreementOnChainState[chainId].accounts,
                sheetState[chainId].accounts,
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

function generateChainUpdates(agreementOnChainState, sheetState) {
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
                        sheetState[chainId].assetRecoveryAddress,
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
        chainsToRemove: currentChainIds.filter(
            (chainId) => !desiredChainIds.includes(chainId),
        ),
        chainsToAdd: desiredChainIds.filter(
            (chainId) => !currentChainIds.includes(chainId),
        ),
    };
}

function assertUpdateInputs(agreementOnChainState, sheetState) {
    const [diagnostic] = validateUpdateInputs(
        agreementOnChainState,
        sheetState,
    );
    if (!diagnostic) {
        return;
    }
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}

function validateUpdateInputs(agreementOnChainState, sheetState) {
    return Object.entries(sheetState).flatMap(([chainId, { accounts }]) => {
        const isNewChain = !agreementOnChainState[chainId];

        return validateChainUpdate(accounts ?? [], isNewChain, chainId);
    });
}

function validateChainUpdate(accounts, isNewChain, chainId) {
    if (accounts.length === 0) {
        return [
            {
                code: isNewChain
                    ? $.ADDED_CHAIN_WITHOUT_ACCOUNTS
                    : $.EXISTING_CHAIN_WITHOUT_ACCOUNTS,
                context: { chainId },
            },
        ];
    }
    if (!isNewChain) {
        return [];
    }

    const invalidAccounts = accounts.filter(
        (account) =>
            !account.accountAddress ||
            !isValidChildContractScope(account.childContractScope),
    );
    if (invalidAccounts.length === 0) {
        return [];
    }
    return [
        {
            code: $.INVALID_NEW_CHAIN_ACCOUNTS,
            context: { chainId, accounts: invalidAccounts },
        },
    ];
}

function isValidChildContractScope(scope) {
    if (
        !["number", "bigint", "string"].includes(typeof scope) ||
        (typeof scope === "string" && scope.trim().length === 0)
    ) {
        return false;
    }
    // ChildContractScope: None = 0, ExistingOnly = 1, All = 2, FutureOnly = 3.
    // Source: https://github.com/security-alliance/safe-harbor/blob/0b0abb8b627eff87e2f7b52bf8ec484cd6ce0e32/registry-contracts/src/types/AgreementTypes.sol
    // Parse integer strings exactly, including hex, as required by ABI encoding.
    try {
        return [0n, 1n, 2n, 3n].includes(BigInt(scope));
    } catch {
        return false;
    }
}
