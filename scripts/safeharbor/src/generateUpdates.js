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
    csvState,
    chainDetails,
    chainsToRemove = [],
) {
    const updates = [];

    // Iterate through each chain that exists in onChainState
    // New chains are handled by generateChainUpdates
    for (const chainName of Object.keys(onChainState)) {
        // Skip chains that are being removed
        if (chainsToRemove.includes(chainName)) {
            console.warn(
                `Skipping account updates for chain ${chainName} - will be removed entirely`,
            );
            continue;
        }

        const chainId = chainDetails.caip2ChainId[chainName];
        const currentAccounts = onChainState[chainName] || [];
        const desiredAccounts = csvState[chainName] || [];

        if (desiredAccounts.length === 0) {
            throw new Error(
                `Chain '${chainName}' must be removed instead of configured without accounts`,
            );
        }

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
            updates.push(encodeUpdate("removeAccounts", [chainId, toRemove]));
        }

        // Handle additions
        if (!removesAllCurrentAccounts && toAdd.length > 0) {
            updates.push(encodeUpdate("addAccounts", [chainId, toAdd]));
        }
    }

    return updates;
}

function generateChainUpdates(onChainState, csvState, chainDetails) {
    const updates = [];

    const currentChainNames = Object.keys(onChainState);
    const desiredChainNames = Object.keys(csvState);

    // Find chains to add and remove
    const chainsToRemove = currentChainNames.filter(
        (chain) => !desiredChainNames.includes(chain),
    );
    const chainsToAdd = desiredChainNames.filter(
        (chain) => !currentChainNames.includes(chain),
    );

    // Remove chains that are no longer in CSV - batch them together
    if (chainsToRemove.length > 0) {
        const chainIdsToRemove = chainsToRemove.map(
            (chainName) => chainDetails.caip2ChainId[chainName],
        );
        updates.push(encodeUpdate("removeChains", [chainIdsToRemove]));
    }

    // Add new chains from CSV - batch them together
    if (chainsToAdd.length > 0) {
        const newChains = chainsToAdd.map((chainName) => {
            const chainId = chainDetails.caip2ChainId[chainName];
            const accounts = csvState[chainName] || [];

            if (accounts.length === 0) {
                throw new Error(
                    `Cannot add chain '${chainName}' without accounts`,
                );
            }

            return {
                assetRecoveryAddress:
                    chainDetails.assetRecoveryAddress[chainName],
                accounts: accounts,
                caip2ChainId: chainId,
            };
        });

        // Debug: Check for undefined values in accounts across all new chains
        newChains.forEach((chain, index) => {
            if (chain.accounts.length > 0) {
                const problematicAccounts = chain.accounts.filter(
                    (acc) =>
                        !acc.accountAddress ||
                        acc.childContractScope === undefined ||
                        acc.childContractScope === null,
                );
                if (problematicAccounts.length > 0) {
                    throw new Error(
                        `Problematic accounts found in chain ${chainsToAdd[index]}: ${JSON.stringify(problematicAccounts)}`,
                    );
                }
            }
        });

        updates.push(encodeUpdate("addChains", [newChains]));
    }

    return { updates, chainsToRemove };
}

// The caller must validate state before generating executable updates.
export function generateUpdates(onChainState, csvState, chainDetails) {
    const { updates: chainUpdates, chainsToRemove } = generateChainUpdates(
        onChainState,
        csvState,
        chainDetails,
    );
    const accountUpdates = generateAccountUpdates(
        onChainState,
        csvState,
        chainDetails,
        chainsToRemove,
    );

    return [...chainUpdates, ...accountUpdates];
}
