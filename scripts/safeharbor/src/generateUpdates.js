import { Interface } from "ethers";
import { AGREEMENT_V3_ABI as AGREEMENT_ABI } from "./abis.js";

const agreementInterface = new Interface(AGREEMENT_ABI);

function encodeUpdate(functionName, args) {
    return {
        function: functionName,
        args,
        calldata: agreementInterface.encodeFunctionData(functionName, args),
    };
}

// Account difference calculation
function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    const currentKeys = new Set(
        currentAccounts.map(
            (acc) => `${acc.accountAddress}-${acc.childContractScope}`,
        ),
    );
    const desiredKeys = new Set(
        desiredAccounts.map(
            (acc) => `${acc.accountAddress}-${acc.childContractScope}`,
        ),
    );

    const toRemove = currentAccounts
        .filter(
            (acc) =>
                !desiredKeys.has(
                    `${acc.accountAddress}-${acc.childContractScope}`,
                ),
        )
        .map((acc) => acc.accountAddress);
    const toAdd = desiredAccounts.filter(
        (acc) =>
            !currentKeys.has(`${acc.accountAddress}-${acc.childContractScope}`),
    );

    return { toAdd, toRemove };
}

function generateAccountUpdates(
    onChainState,
    sheetState,
    chainDetails,
    chainsToRemove = [],
) {
    const updates = [];

    // Iterate through each chain that exists in onChainState
    // New chains are handled by generateChainUpdates
    for (const chainName of Object.keys(onChainState)) {
        // Skip chains that are being removed
        if (chainsToRemove.includes(chainName)) {
            continue;
        }

        const chainId = chainDetails.caip2ChainId[chainName];
        const currentAccounts = onChainState[chainName] || [];
        const desiredAccounts = sheetState[chainName] || [];

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts.accounts,
            desiredAccounts,
        );

        const removesAllCurrentAccounts =
            toRemove.length === currentAccounts.accounts.length;

        // Add replacements first if removing first would leave the chain empty.
        if (removesAllCurrentAccounts && toAdd.length > 0) {
            updates.push(encodeUpdate("addAccounts", [chainId, toAdd]));
        }

        // Handle removals - removeAccounts now takes addresses directly
        if (toRemove.length > 0) {
            // Reverse full replacements so swap-and-pop cannot remove a new scope.
            updates.push(
                encodeUpdate("removeAccounts", [
                    chainId,
                    removesAllCurrentAccounts
                        ? [...toRemove].reverse()
                        : toRemove,
                ]),
            );
        }

        // Handle additions
        if (!removesAllCurrentAccounts && toAdd.length > 0) {
            updates.push(encodeUpdate("addAccounts", [chainId, toAdd]));
        }
    }

    return updates;
}

function generateChainUpdates(onChainState, sheetState, chainDetails) {
    const updates = [];

    const currentChainNames = Object.keys(onChainState);
    const desiredChainNames = Object.keys(sheetState);

    // Find chains to add and remove
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
        updates.push(encodeUpdate("removeChains", [chainIdsToRemove]));
    }

    // Add new chains from the Safeharbor Sheet - batch them together
    if (chainsToAdd.length > 0) {
        const newChains = chainsToAdd.map((chainName) => {
            const chainId = chainDetails.caip2ChainId[chainName];
            const accounts = sheetState[chainName] || [];

            return {
                assetRecoveryAddress:
                    chainDetails.assetRecoveryAddress[chainName],
                accounts: accounts,
                caip2ChainId: chainId,
            };
        });

        updates.push(encodeUpdate("addChains", [newChains]));
    }

    return { updates, chainsToRemove };
}

// The caller must validate state before generating executable updates.
export function generateUpdates(onChainState, sheetState, chainDetails) {
    const [diagnostic] = validateUpdateInputs(onChainState, sheetState);
    if (diagnostic) {
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }

    const { updates: chainUpdates, chainsToRemove } = generateChainUpdates(
        onChainState,
        sheetState,
        chainDetails,
    );
    const accountUpdates = generateAccountUpdates(
        onChainState,
        sheetState,
        chainDetails,
        chainsToRemove,
    );

    return [...chainUpdates, ...accountUpdates];
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
                            ? "ADDED_CHAIN_WITHOUT_ACCOUNTS"
                            : "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
                        context: { chainName },
                    },
                ];
            }
            if (!isNewChain) return [];

            const invalidAccounts = accounts.filter(
                (account) =>
                    !account.accountAddress ||
                    account.childContractScope === undefined ||
                    account.childContractScope === null,
            );
            return invalidAccounts.length > 0
                ? [
                      {
                          code: "INVALID_NEW_CHAIN_ACCOUNTS",
                          context: { chainName, accounts: invalidAccounts },
                      },
                  ]
                : [];
        },
    );
}
