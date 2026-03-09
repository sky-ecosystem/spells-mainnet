import { Interface } from "ethers";
import { AGREEMENT_V3_ABI as AGREEMENT_ABI } from "./abis.js";

const agreementInterface = new Interface(AGREEMENT_ABI);

/**
 * @typedef {Object} SafeHarborAccount
 * @property {string} accountAddress
 * @property {number} childContractScope
 */

/**
 * @typedef {Object} SafeHarborChainState
 * @property {SafeHarborAccount[]} accounts
 * @property {string} assetRecoveryAddress
 */

/**
 * @typedef {Object} ChainDetails
 * @property {Record<string, string>} caip2ChainId
 * @property {Record<string, string>} assetRecoveryAddress
 */

/**
 * @typedef {Object} AgreementUpdate
 * @property {string} function
 * @property {Array<any>} args
 * @property {string} calldata
 */

/**
 * Compares the current and desired accounts for a single chain and derives the
 * minimal add/remove operations required to synchronize them.
 *
 * Accounts are keyed by the pair `{accountAddress, childContractScope}` so that
 * the same address can be tracked under different scopes.
 *
 * @param {SafeHarborAccount[]} currentAccounts
 * @param {SafeHarborAccount[]} desiredAccounts
 * @returns {{
 *   toAdd: SafeHarborAccount[],
 *   toRemove: string[],
 * }}
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
 * Generates `addAccounts` and `removeAccounts` updates for chains that already
 * exist on-chain and are not scheduled for removal.
 *
 * @param {Record<string, SafeHarborChainState>} onChainState
 * @param {Record<string, SafeHarborAccount[]>} csvState
 * @param {ChainDetails} chainDetails
 * @param {string[]} [chainsToRemove=[]]
 * @returns {AgreementUpdate[]}
 */
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

/**
 * Warns when the asset recovery address configured on-chain differs from the
 * value provided in the chain details sheet for the same chain.
 *
 * This is intentionally non-blocking because account updates can still be
 * generated even when the recovery address is inconsistent.
 *
 * @param {Record<string, SafeHarborChainState>} onChainState
 * @param {Record<string, SafeHarborAccount[]>} csvState
 * @param {ChainDetails} chainDetails
 * @returns {void}
 */
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

/**
 * Generates `addChains` and `removeChains` updates by comparing the set of
 * chains already registered on-chain with the chains present in the CSV input.
 *
 * Chains that are present in the CSV but missing from `chainDetails` are
 * ignored and reported as warnings.
 *
 * @param {Record<string, SafeHarborChainState>} onChainState
 * @param {Record<string, SafeHarborAccount[]>} csvState
 * @param {ChainDetails} chainDetails
 * @returns {{
 *   updates: AgreementUpdate[],
 *   chainsToRemove: string[],
 * }}
 */
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

/**
 * Produces the ordered agreement updates required to reconcile the on-chain
 * SafeHarbor agreement state with the CSV-derived desired state.
 *
 * Chain-level changes are generated first so that account-level updates are not
 * produced for chains that will be removed entirely in the same batch.
 *
 * @param {Record<string, SafeHarborChainState>} onChainState
 * @param {Record<string, SafeHarborAccount[]>} csvState
 * @param {ChainDetails} chainDetails
 * @returns {AgreementUpdate[]}
 */
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
