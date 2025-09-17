import { Interface } from "ethers";
import { AGREEMENTV2_ABI } from "./abis.js";
import { getChainId, getAssetRecoveryAddress } from "./utils/chainUtils.js";

const agreementInterface = new Interface(AGREEMENTV2_ABI);

/**
 * Compute which accounts need to be added or removed to transform currentAccounts into desiredAccounts.
 *
 * Compares accounts by the composite key (accountAddress + childContractScope). Returns
 * an object with `toAdd` — entries present in desiredAccounts but not in currentAccounts
 * (each entry includes `accountAddress` and `childContractScope`) — and `toRemove` —
 * an array of `accountAddress` values for entries present in currentAccounts but not in desiredAccounts.
 *
 * @param {Array<{accountAddress: string, childContractScope: string}>} currentAccounts - Current on-chain account records.
 * @param {Array<{accountAddress: string, childContractScope: string}>} desiredAccounts - Desired target account records (from CSV).
 * @return {{ toAdd: Array<{accountAddress: string, childContractScope: string}>, toRemove: string[] }}
 */
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

/**
 * Build account-level update payloads (add/remove accounts) for each on-chain chain not slated for removal.
 *
 * Iterates over chains present in onChainState and computes per-chain account differences against csvState.
 * For each chain (except those listed in `chainsToRemove`) it produces zero or more update objects:
 * - removeAccounts: calldata and args to remove addresses for that chain (if any),
 * - addAccounts: calldata and args to add accounts for that chain (if any).
 *
 * @param {Object<string, Array<Object>>} onChainState - Mapping of chainName → array of current account objects.
 * @param {Object<string, Array<Object>>} csvState - Mapping of chainName → array of desired account objects from CSV.
 * @param {Array<string>} [chainsToRemove=[]] - Chain names that will be removed; account updates for these chains are skipped.
 * @returns {Array<Object>} Array of update objects. Each object has the shape { function: string, args: Array, calldata: string }.
 */
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

/**
 * Generate chain-level update payloads to add/remove chains so on-chain state matches CSV state.
 *
 * Compares chains present in onChainState and csvState, producing encoded "addChains" and
 * "removeChains" update objects (batched per operation) suitable for submission via the agreement ABI.
 *
 * Parameters:
 * - onChainState: map of chainName -> array of existing chain accounts (current on-chain representation).
 * - csvState: map of chainName -> array of desired chain accounts (desired CSV representation).
 *
 * Returns an object with:
 * - updates: Array of update descriptors { function, args, calldata } for chain-level operations.
 * - chainsToRemove: Array of chain names that were present on-chain but absent from csvState.
 *
 * Throws an Error if any account objects in newly added chains are missing required fields
 * (missing `accountAddress` or undefined/null `childContractScope`).
 */
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

/**
 * Produce the ordered list of on-chain update payloads needed to reconcile on-chain state with CSV-defined desired state.
 *
 * Generates chain-level updates (add/remove chains) first, then account-level updates (add/remove accounts) for remaining chains,
 * and returns the combined array of update objects ready for encoding/execution.
 *
 * @param {Object<string, Array>} onChainState - Current on-chain mapping from chain name to an array of account objects.
 * @param {Object<string, Array>} csvState - Desired mapping from chain name to an array of account objects as parsed from CSV.
 * @return {Array<Object>} Ordered array of update objects (each contains function name, args, and calldata) representing the changes to apply.
 */
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

    return [...chainUpdates, ...accountUpdates];
}
