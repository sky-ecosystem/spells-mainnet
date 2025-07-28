import { downloadAndParseCSV } from "./utils/csvUtils.js";
import { getAssetRecoveryAddress } from "./utils/chainUtils.js";

// Constants
import { CSV_URL_SHEET1 } from "./constants.js";

import {
    createProvider,
    createContractInstances,
} from "./utils/contractUtils.js";
import { getChainId, getChainName } from "./utils/chainUtils.js";
import { writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { AGREEMENTV2_RAW_ABI_MAP } from "./abis.js";

// Helper function to compare arrays
export function arraysEqual(a, b) {
    if (a.length !== b.length) return false;
    return a.every((val, index) => val === b[index]);
}

// Helper function to find differences between arrays
export function findArrayDifferences(current, desired) {
    const toAdd = desired.filter((item) => !current.includes(item));
    const toRemove = current.filter((item) => !desired.includes(item));
    return { toAdd, toRemove };
}

// Build internal representation from CSV
export function normalizeDataFromCSV(records) {
    return records
        .filter((record) => record.Status === "ACTIVE")
        .reduce((groups, record) => {
            const chain = record.Chain;
            if (!groups[chain]) {
                groups[chain] = [];
            }
            groups[chain].push({
                accountAddress: record.Address,
                childContractScope: record.IsFactory === "TRUE" ? 3 : 0,
                isFactory: record.IsFactory === "TRUE",
            });
            return groups;
        }, {});
}

// Build internal representation from on-chain state
export function normalizeDataFromOnchainState(details) {
    return details.chains.reduce((groups, chain) => {
        const chainName = getChainName(chain.id);
        groups[chainName] = chain.accounts;
        return groups;
    }, {});
}

// Generate human-readable diffs
export function generateHumanReadableDiffs(csvState, onChainState) {
    const diffs = [];

    // Compare chains
    const csvChains = Object.keys(csvState);
    const onChainChains = Object.keys(onChainState);

    // Find chain differences
    const { toAdd: chainsToAdd, toRemove: chainsToRemove } =
        findArrayDifferences(onChainChains, csvChains);

    // Add chain diffs
    chainsToAdd.forEach((chain) => {
        diffs.push(
            `Add chain ${chain} with ${csvState[chain].length} accounts:`,
        );
        csvState[chain].forEach((account) => {
            const factoryNote = account.isFactory ? " (Factory)" : "";
            diffs.push(`  - Add ${account.accountAddress}${factoryNote}`);
        });
    });

    chainsToRemove.forEach((chain) => {
        diffs.push(
            `Remove chain ${chain} with ${onChainState[chain].length} accounts`,
        );
    });

    // Compare accounts for each common chain
    const commonChains = csvChains.filter((chain) =>
        onChainChains.includes(chain),
    );
    commonChains.forEach((chain) => {
        const csvAccounts = csvState[chain].map((acc) => acc.accountAddress);
        const onChainAccounts = onChainState[chain].map(
            (acc) => acc.accountAddress,
        );

        const { toAdd, toRemove } = findArrayDifferences(
            onChainAccounts,
            csvAccounts,
        );

        toAdd.forEach((addr) => {
            const account = csvState[chain].find(
                (acc) => acc.accountAddress === addr,
            );
            const factoryNote = account.isFactory ? " (Factory)" : "";
            diffs.push(`Add ${addr}${factoryNote} to ${chain}`);
        });

        toRemove.forEach((addr) => {
            diffs.push(`Remove ${addr} from ${chain}`);
        });
    });

    return diffs;
}

// Data fetching and standardization
export async function fetchAgreementDetails() {
    const provider = createProvider();
    const { agreement } = createContractInstances(provider);
    return await agreement.getDetails();
}

// Account difference calculation
export function calculateAccountDifferences(currentAccounts, desiredAccounts) {
    const accountDiff = findArrayDifferences(
        currentAccounts.map((account) => account.accountAddress),
        desiredAccounts.map((contract) => contract.accountAddress),
    );

    return {
        toAdd: accountDiff.toAdd.map((address) => {
            const account = desiredAccounts.find(
                (acc) => acc.accountAddress === address,
            );
            return {
                accountAddress: address,
                childContractScope: account.isFactory ? 3 : 0,
            };
        }),
        toRemove: accountDiff.toRemove,
    };
}

// Update payload generation
export function generateChainUpdates(currentChains, chainGroups) {
    const updates = [];
    const currentChainIds = currentChains.map((chain) => chain.id.toString());
    const desiredChainIds = Object.entries(chainGroups).map(([chain]) =>
        getChainId(chain).toString(),
    );
    const chainDiff = findArrayDifferences(currentChainIds, desiredChainIds);

    const provider = createProvider();
    const { agreement } = createContractInstances(provider);

    for (const chainId of chainDiff.toRemove) {
        updates.push({
            function: "removeChain",
            args: [chainId],
            calldata: agreement.interface.encodeFunctionData("removeChain", [
                chainId,
            ]),
            "raw-abi": AGREEMENTV2_RAW_ABI_MAP["removeChain"],
        });
    }

    for (const chainId of chainDiff.toAdd) {
        const chainName = getChainName(parseInt(chainId));
        const chainContracts = chainGroups[chainName] || [];

        const newChain = {
            assetRecoveryAddress: getAssetRecoveryAddress(chainName),
            accounts: chainContracts,
            id: parseInt(chainId),
        };

        updates.push({
            function: "addChains",
            args: [[newChain]],
            calldata: agreement.interface.encodeFunctionData("addChains", [
                [newChain],
            ]),
            "raw-abi": AGREEMENTV2_RAW_ABI_MAP["addChains"],
        });
    }

    return updates;
}

export function generateAccountUpdates(currentChains, chainGroups) {
    const updates = [];
    const provider = createProvider();
    const { agreement } = createContractInstances(provider);

    for (const [chainId, chain] of currentChains.entries()) {
        const chainName = getChainName(chain.id);
        const desiredAccounts = chainGroups[chainName] || [];
        const currentAccounts = chain.accounts;

        const { toAdd, toRemove } = calculateAccountDifferences(
            currentAccounts,
            desiredAccounts,
        );

        // First, try to replace accounts in place
        const accountIds = [];
        const newAccounts = [];

        // Match removals with additions to replace in place
        const minLength = Math.min(toRemove.length, toAdd.length);
        for (let i = 0; i < minLength; i++) {
            const index = currentAccounts.findIndex(
                (acc) => acc.accountAddress === toRemove[i],
            );
            if (index !== -1) {
                accountIds.push(index);
                newAccounts.push(toAdd[i]);
            }
        }

        // If we have any replacements to make, do them first
        if (accountIds.length > 0) {
            updates.push({
                function: "setAccounts",
                args: [chainId, accountIds, newAccounts],
                calldata: agreement.interface.encodeFunctionData(
                    "setAccounts",
                    [chainId, accountIds, newAccounts],
                ),
                "raw-abi": AGREEMENTV2_RAW_ABI_MAP["setAccounts"],
            });
        }

        // Handle remaining removals (if any)
        const remainingRemovals = toRemove.slice(minLength);
        if (remainingRemovals.length > 0) {
            const sortedIndices = remainingRemovals
                .map((addr) =>
                    currentAccounts.findIndex(
                        (acc) => acc.accountAddress === addr,
                    ),
                )
                .sort((a, b) => b - a);

            for (const index of sortedIndices) {
                updates.push({
                    function: "removeAccount",
                    args: [chainId, index],
                    calldata: agreement.interface.encodeFunctionData(
                        "removeAccount",
                        [chainId, index],
                    ),
                    "raw-abi": AGREEMENTV2_RAW_ABI_MAP["removeAccount"],
                });
            }
        }

        // Handle remaining additions (if any)
        const remainingAdditions = toAdd.slice(minLength);
        if (remainingAdditions.length > 0) {
            updates.push({
                function: "addAccounts",
                args: [chainId, remainingAdditions],
                calldata: agreement.interface.encodeFunctionData(
                    "addAccounts",
                    [chainId, remainingAdditions],
                ),
                "raw-abi": AGREEMENTV2_RAW_ABI_MAP["addAccounts"],
            });
        }
    }

    return updates;
}

// Main function
export async function generateUpdatePayload() {
    try {
        // 1. Download and parse CSV
        console.log("Downloading Google Sheet CSV...");
        const records = await downloadAndParseCSV(CSV_URL_SHEET1);

        const csvState = normalizeDataFromCSV(records);

        // 2. Fetch on-chain state
        console.log("Fetching on-chain state...");
        const currentDetails = await fetchAgreementDetails();
        const onChainState = normalizeDataFromOnchainState(currentDetails);

        // 3. Generate human-readable diffs
        const diffs = generateHumanReadableDiffs(csvState, onChainState);
        console.log("\nChanges to be made:");
        diffs.forEach((diff) => console.log(diff));

        // 4. Generate updates
        const chainUpdates = generateChainUpdates(
            currentDetails.chains,
            csvState,
        );
        const accountUpdates = generateAccountUpdates(
            currentDetails.chains,
            csvState,
        );
        const updates = [...chainUpdates, ...accountUpdates];

        // 5. Display and save payload
        console.log("\nGenerated payload:");

        // Save updates to JSON file
        const __filename = fileURLToPath(import.meta.url);
        const __dirname = dirname(__filename);
        const outputPath = join(__dirname, "..", "updates.json");
        writeFileSync(outputPath, JSON.stringify(updates, null, 2));
        console.log(`\nSaved updates to ${outputPath}`);

        return updates;
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}

// Only run if this file is being executed directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
    generateUpdatePayload();
}
