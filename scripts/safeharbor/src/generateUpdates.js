import { ethers } from "ethers";
import { AGREEMENTV2_ABI, MULTICALL_ABI } from "./abis.js";
import { getChainId, getAssetRecoveryAddress } from "./utils/chainUtils.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

const agreementInterface = new ethers.utils.Interface(AGREEMENTV2_ABI);
const multicallInterface = new ethers.utils.Interface(MULTICALL_ABI);

/**
 * Compute account additions and removals required to transform currentAccounts into desiredAccounts.
 *
 * Compares accounts by the composite key `${accountAddress}-${childContractScope}`. Returns
 * `toAdd` as an array of account objects ({ accountAddress, childContractScope }) that are present
 * in desiredAccounts but not in currentAccounts, and `toRemove` as an array of accountAddress strings
 * that are present in currentAccounts but not in desiredAccounts.
 *
 * @param {Array<Object>} currentAccounts - Existing on-chain accounts. Each object must include
 *   `accountAddress` (string) and `childContractScope` (string or value used to scope the account).
 * @param {Array<Object>} desiredAccounts - Desired accounts state with the same object shape.
 * @returns {{ toAdd: Array<{accountAddress: string, childContractScope: *}>, toRemove: string[] }}
 */
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

/**
 * Build per-chain account update calls (add/remove) by comparing on-chain state to CSV state.
 *
 * For each chain present in onChainState (except those listed in chainsToRemove), computes account
 * differences and returns encoded update objects for `removeAccounts` and `addAccounts` as needed.
 *
 * @param {Object<string, Array<Object>>} onChainState - Current on-chain account mapping keyed by chain name.
 *   Each value is an array of account entries as stored on-chain.
 * @param {Object<string, Array<Object>>} csvState - Desired account mapping keyed by chain name from CSV input.
 *   Each value is an array of desired account entries (objects containing at least `accountAddress` and `childContractScope`).
 * @param {Array<string>} [chainsToRemove=[]] - Chain names that will be removed entirely; account updates for these chains are skipped.
 * @return {Array<Object>} Array of update objects. Each update includes `function`, `args`, and encoded `calldata`
 *   suitable for submission to the Agreement contract.
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
 * Compute chain-level on-chain updates needed to reconcile onChainState with csvState.
 *
 * Builds batched "removeChains" and "addChains" update entries (with encoded calldata)
 * for chains that should be removed or added, respectively.
 *
 * @param {Object<string, any>} onChainState - Mapping of current chainName -> on-chain chain data.
 * @param {Object<string, any>} csvState - Mapping of desired chainName -> desired chain data (accounts, etc.).
 * @returns {{ updates: Array<Object>, chainsToRemove: string[] }} An object containing:
 *   - updates: array of update objects (each has `function`, `args`, and `calldata`) for add/remove chain calls.
 *   - chainsToRemove: list of chain names that will be removed.
 * @throws {Error} If any account in a chain being added is missing an `accountAddress` or has an undefined/null `childContractScope`.
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
 * Wraps a list of encoded Agreement contract updates into a single Multicall aggregate call.
 *
 * If `updates` is empty, the same array is returned unchanged. Otherwise this returns a new
 * array containing the original updates plus one additional update that calls the Multicall
 * contract's `aggregate` with the individual updates' calldata targeted at the Agreement.
 *
 * @param {Array<Object>} updates - Array of update objects; each must include a `calldata` field (encoded Agreement call).
 * @param {string} agreementContractAddress - Address of the Agreement contract; used as the target for aggregated calls.
 * @param {string} multicallContractAddress - Address of the Multicall contract which will be called with the aggregated payload.
 * @return {Array<Object>} A new array containing the original updates and a final multicall update (unless `updates` was empty).
 */
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

/**
 * Build the set of on-chain update operations (chain and account changes) and wrap them in a multicall.
 *
 * Generates chain-level and account-level update calls by comparing the current on-chain state to the desired CSV state,
 * then bundles all resulting calldata into a single multicall targeting the configured multicall contract.
 *
 * @param {Object} onChainState - Current on-chain representation keyed by chain name; values include existing accounts and chain metadata.
 * @param {Object} csvState - Desired state parsed from CSV, keyed by chain name with account lists to apply.
 * @return {Array<Object>} An array of update objects. If any updates exist they are additionally wrapped as a single multicall update; otherwise returns an empty array.
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
    return wrapWithMulticall(
        [...chainUpdates, ...accountUpdates],
        AGREEMENT_ADDRESS,
        MULTICALL_ADDRESS,
    );
}
