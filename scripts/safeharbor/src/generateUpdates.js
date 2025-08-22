import { Interface } from "ethers";
import { AGREEMENTV2_ABI, MULTICALL_ABI } from "./abis.js";
import { getChainId, getAssetRecoveryAddress } from "./utils/chainUtils.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

const agreementInterface = new Interface(AGREEMENTV2_ABI);
const multicallInterface = new Interface(MULTICALL_ABI);

// Account difference calculation
export function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    // Create maps for easier lookup with composite keys
    const currentMap = new Map(
        currentAccounts.map((acc) => [
            `${acc.accountAddress}-${acc.childContractScope}`,
            acc,
        ]),
    );

    const desiredMap = new Map(
        desiredAccounts.map((acc) => [
            `${acc.accountAddress}-${acc.childContractScope}`,
            acc,
        ]),
    );

    // Find accounts to remove (exist in current but not in desired with same scope)
    const toRemove = currentAccounts
        .filter(
            (acc) =>
                !desiredMap.has(
                    `${acc.accountAddress}-${acc.childContractScope}`,
                ),
        )
        .map((acc) => acc.accountAddress);

    // Find accounts to add (exist in desired but not in current with same scope)
    const toAdd = desiredAccounts
        .filter(
            (acc) =>
                !currentMap.has(
                    `${acc.accountAddress}-${acc.childContractScope}`,
                ),
        )
        .map((acc) => ({
            accountAddress: acc.accountAddress,
            childContractScope: acc.childContractScope,
        }));

    return { toAdd, toRemove };
}

function generateAccountUpdates(onChainState, csvState, chainsToRemove = []) {
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

        const chainId = getChainId(chainName);
        const currentAccounts = onChainState[chainName] || [];
        const desiredAccounts = csvState[chainName] || [];

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts,
            desiredAccounts,
        );

        // Handle removals - removeAccounts now takes addresses directly
        if (toRemove.length > 0) {
            updates.push({
                function: "removeAccounts",
                args: [chainId, toRemove],
                calldata: agreementInterface.encodeFunctionData(
                    "removeAccounts",
                    [chainId, toRemove],
                ),
            });
        }

        // Handle additions
        if (toAdd.length > 0) {
            updates.push({
                function: "addAccounts",
                args: [chainId, toAdd],
                calldata: agreementInterface.encodeFunctionData("addAccounts", [
                    chainId,
                    toAdd,
                ]),
            });
        }
    }

    return updates;
}

function generateChainUpdates(onChainState, csvState) {
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
        const chainIdsToRemove = chainsToRemove.map((chainName) =>
            getChainId(chainName),
        );
        updates.push({
            function: "removeChains",
            args: [chainIdsToRemove],
            calldata: agreementInterface.encodeFunctionData("removeChains", [
                chainIdsToRemove,
            ]),
        });
    }

    // Add new chains from CSV - batch them together
    if (chainsToAdd.length > 0) {
        const newChains = chainsToAdd.map((chainName) => {
            const chainId = getChainId(chainName);
            const accounts = csvState[chainName] || [];

            return {
                assetRecoveryAddress: getAssetRecoveryAddress(chainName),
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

        updates.push({
            function: "addChains",
            args: [newChains],
            calldata: agreementInterface.encodeFunctionData("addChains", [
                newChains,
            ]),
        });
    }

    return { updates, chainsToRemove };
}

function wrapWithMulticall(
    updates,
    agreementContractAddress,
    multicallContractAddress,
) {
    // If no updates, return the original array
    if (updates.length === 0) {
        return updates;
    }

    // Convert individual updates to multicall format
    const calls = updates.map((update) => ({
        target: agreementContractAddress,
        callData: update.calldata,
    }));

    // Generate multicall calldata
    const multicallCalldata = multicallInterface.encodeFunctionData(
        "aggregate",
        [calls],
    );

    // Add the multicall update to the array
    const multicallUpdate = {
        function: "multicall",
        args: [calls],
        calldata: multicallCalldata,
        target: multicallContractAddress,
    };

    // Return original updates plus the multicall wrapper
    return [...updates, multicallUpdate];
}

export function generateUpdates(onChainState, csvState) {
    const { updates: chainUpdates, chainsToRemove } = generateChainUpdates(
        onChainState,
        csvState,
    );
    const accountUpdates = generateAccountUpdates(
        onChainState,
        csvState,
        chainsToRemove,
    );
    return wrapWithMulticall(
        [...chainUpdates, ...accountUpdates],
        AGREEMENT_ADDRESS,
        MULTICALL_ADDRESS,
    );
}
