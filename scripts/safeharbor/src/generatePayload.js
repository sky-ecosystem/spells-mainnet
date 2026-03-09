import {
    getChainDetailsFromCSV,
    getNormalizedContractsInScopeFromCSV,
} from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { generateSolidityCode } from "./utils/generateSolidity.js";
import {
    CONTRACTS_IN_SCOPE_SHEET_URL,
    CHAIN_DETAILS_SHEET_URL,
} from "./constants.js";

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
 * @property {Record<string, string>} name
 */

/**
 * @typedef {Object} AgreementUpdate
 * @property {string} function
 * @property {Array<any>} args
 * @property {string} calldata
 */

/**
 * @typedef {Object} GeneratePayloadResult
 * @property {AgreementUpdate[]} updates
 * @property {string} solidityCode
 */

/**
 * Generates the SafeHarbor agreement update payload by reconciling the desired
 * CSV-backed state with the current on-chain agreement state.
 *
 * This function orchestrates the entire payload generation process:
 * 1. Fetches chain metadata from the chain-details CSV
 * 2. Fetches and normalizes the contracts-in-scope CSV
 * 3. Fetches and normalizes the on-chain agreement state
 * 4. Computes the required agreement updates
 * 5. Produces Solidity code for those updates
 *
 * If the agreement is already in sync with the CSV inputs, the function returns
 * an empty update list and an empty Solidity snippet.
 *
 * @param {{
 *   address: string,
 *   getDetails: () => Promise<{ chains: Array<{
 *     caip2ChainId: string,
 *     assetRecoveryAddress: string,
 *     accounts: Array<[string, number]>,
 *   }> }>,
 * }} agreementContract Ethers contract instance for the SafeHarbor Agreement deployment.
 * @returns {Promise<GeneratePayloadResult>}
 * @throws {Error} If CSV download, on-chain reads, diff generation, or
 * Solidity snippet generation fails.
 *
 * @example
 * const agreementContract = createAgreementInstance(rpcUrl);
 * const result = await generatePayload(agreementContract);
 * console.log(result.solidityCode);
 */
export async function generatePayload(agreementContract) {
    try {
        // 0. Fetch chain information once at the beginning
        console.warn("Fetching chains details CSV...");
        const chainDetails = await getChainDetailsFromCSV(
            CHAIN_DETAILS_SHEET_URL,
        );

        // 1. Download and parse CSV
        console.warn("Downloading contracts in scope CSV...");
        const csvState = await getNormalizedContractsInScopeFromCSV(
            CONTRACTS_IN_SCOPE_SHEET_URL,
        );

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        const onChainState = await getNormalizedDataFromOnchainState(
            agreementContract,
            chainDetails,
        );

        // 3. Generate updates
        console.warn("Generating updates...");
        const updates = generateUpdates(onChainState, csvState, chainDetails);

        if (updates.length === 0) {
            return {
                updates: [],
                solidityCode: "",
            };
        }

        // 4. Generate solidity code
        const solidityCode = generateSolidityCode(updates);

        return {
            updates,
            solidityCode,
        };
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
