import { ethers } from "ethers";
import { AGREEMENTV2_ABI, AGREEMENTV2_RAW_ABI_MAP } from "./abis.js";
import { getChainId, getAssetRecoveryAddress } from "./utils/chainUtils.js";

const agreementInterface = new ethers.utils.Interface(AGREEMENTV2_ABI);

// Helper function to find differences between arrays
function findArrayDifferences(current, desired) {
    const toAdd = desired.filter((item) => !current.includes(item));
    const toRemove = current.filter((item) => !desired.includes(item));
    return { toAdd, toRemove };
}

// Account difference calculation
export function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    // Create maps for easier lookup with composite keys
    const currentMap = new Map(
        currentAccounts.map(acc => [
            `${acc.accountAddress}-${acc.childContractScope}`,
            acc
        ])
    );
    
    const desiredMap = new Map(
        desiredAccounts.map(acc => [
            `${acc.accountAddress}-${acc.childContractScope}`,
            acc
        ])
    );
    
    // Find accounts to remove (exist in current but not in desired with same scope)
    const toRemove = currentAccounts
        .filter(acc => !desiredMap.has(`${acc.accountAddress}-${acc.childContractScope}`))
        .map(acc => acc.accountAddress);
    
    // Find accounts to add (exist in desired but not in current with same scope)
    const toAdd = desiredAccounts
        .filter(acc => !currentMap.has(`${acc.accountAddress}-${acc.childContractScope}`))
        .map(acc => ({
            accountAddress: acc.accountAddress,
            childContractScope: acc.childContractScope
        }));
    
    return { toAdd, toRemove };
}

function generateAccountUpdates(onChainState, csvState) {
    const updates = [];

    // Iterate through each chain that exists in onChainState
    // New chains are handled by generateChainUpdates
    for (const chainName of Object.keys(onChainState)) {
        const chainId = getChainId(chainName);
        const currentAccounts = onChainState[chainName] || [];
        const desiredAccounts = csvState[chainName] || [];

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts,
            desiredAccounts,
        );

        // Handle removals first
        // Sort indices in descending order to avoid index shifting issues
        if (toRemove.length > 0) {
            const sortedIndices = toRemove
                .map((addr) =>
                    currentAccounts.findIndex(
                        (acc) => acc.accountAddress === addr,
                    ),
                )
                .filter(index => index !== -1)
                .sort((a, b) => b - a);

            for (const index of sortedIndices) {
                updates.push({
                    function: "removeAccount",
                    args: [chainId, index],
                    calldata: agreementInterface.encodeFunctionData(
                        "removeAccount",
                        [chainId, index],
                    ),
                    "raw-abi": AGREEMENTV2_RAW_ABI_MAP["removeAccount"],
                });
            }
        }

        // Handle additions
        if (toAdd.length > 0) {
            updates.push({
                function: "addAccounts",
                args: [chainId, toAdd],
                calldata: agreementInterface.encodeFunctionData(
                    "addAccounts",
                    [chainId, toAdd],
                ),
                "raw-abi": AGREEMENTV2_RAW_ABI_MAP["addAccounts"],
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
    const chainsToRemove = currentChainNames.filter(chain => !desiredChainNames.includes(chain));
    const chainsToAdd = desiredChainNames.filter(chain => !currentChainNames.includes(chain));
    
    // Remove chains that are no longer in CSV
    for (const chainName of chainsToRemove) {
        const chainId = getChainId(chainName);
        updates.push({
            function: "removeChain",
            args: [chainId],
            calldata: agreementInterface.encodeFunctionData("removeChain", [
                chainId,
            ]),
            "raw-abi": AGREEMENTV2_RAW_ABI_MAP["removeChain"],
        });
    }
    
    // Add new chains from CSV
    for (const chainName of chainsToAdd) {
        const chainId = getChainId(chainName);
        const accounts = csvState[chainName] || [];
        
        const newChain = {
            assetRecoveryAddress: getAssetRecoveryAddress(chainName),
            accounts: accounts,
            id: chainId,
        };
        
        updates.push({
            function: "addChains",
            args: [[newChain]],
            calldata: agreementInterface.encodeFunctionData("addChains", [
                [newChain],
            ]),
            "raw-abi": AGREEMENTV2_RAW_ABI_MAP["addChains"],
        });
    }
    
    return updates;
}

export function generateUpdates(onChainState, csvState) {
    const chainUpdates = generateChainUpdates(onChainState, csvState);
    const accountUpdates = generateAccountUpdates(onChainState, csvState);
    return [...chainUpdates, ...accountUpdates];
}
