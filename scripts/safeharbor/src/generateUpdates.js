import { Interface } from "ethers";
import { AGREEMENTV2_ABI } from "./abis.js";

const agreementInterface = new Interface(AGREEMENTV2_ABI);

// Account difference calculation
function calculateAccountDifferences(currentAccounts, desiredAccounts) {
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

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts.accounts,
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

function validateRecoveryAddress(onChainState, csvState, chainDetails) {
    const onChainChains = new Set(Object.keys(onChainState));
    const csvChains = new Set(Object.keys(csvState));

    const commonChains = [...onChainChains].filter((chain) =>
        csvChains.has(chain),
    );

    for (const chainName of commonChains) {
        const onchainRecoveryAddress =
            onChainState[chainName].assetRecoveryAddress;
        const csvRecoveryAddress = chainDetails.assetRecoveryAddress[chainName];

        if (
            onchainRecoveryAddress &&
            csvRecoveryAddress &&
            onchainRecoveryAddress.toLowerCase() !==
                csvRecoveryAddress.toLowerCase()
        ) {
            console.warn(
                `\n\n‼️-----‼️ \nAsset Recovery Address mismatch for chain '${chainName}'. \nOn-chain: ${onchainRecoveryAddress} \nCSV:      ${csvRecoveryAddress} \n‼️-----‼️\n\n`,
            );
        }
    }
}

function generateChainUpdates(onChainState, csvState, chainDetails) {
    const updates = [];

    const currentChainNames = Object.keys(onChainState);
    const chainDetailsChainNames = Object.keys(chainDetails.caip2ChainId);
    let desiredChainNames = Object.keys(csvState);

    // Filter out chains that don't have complete details
    desiredChainNames = desiredChainNames.filter((chainName) => {
        if (!chainDetailsChainNames.includes(chainName)) {
            console.warn(
                `\n\n⚠️-----⚠️ \nUnknown chain details in CSV: name='${chainName}' \nInclude chain details to the chain details tab in the Google Sheet to add coverage to it. \n⚠️-----⚠️\n\n`,
            );
            return false;
        }

        return true;
    });

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
            const chainId = chainDetails.caip2ChainId[chainName];
            const accounts = csvState[chainName] || [];

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

export function generateUpdates(onChainState, csvState, chainDetails) {
    validateRecoveryAddress(onChainState, csvState, chainDetails);

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
