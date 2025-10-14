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
 * Main function to generate update payload for SafeHarbor agreement
 * 
 * This function orchestrates the entire payload generation process:
 * 1. Fetches chain details from CSV
 * 2. Downloads and parses contracts in scope CSV
 * 3. Fetches on-chain state for each contract
 * 4. Generates updates based on differences
 * 5. Generates Solidity code for the updates
 * 
 * @async
 * @function generatePayload
 * @param {Object} agreementContract - The ethers.js agreement contract instance
 * @param {string} agreementContract.address - The address of the agreement contract
 * @returns {Promise<{updates: Array<{function: string, args: Array<any>, calldata: string}>, solidityCode: string}>} Object containing:
 *   - updates: Array of update objects with function calls and calldata
 *   - solidityCode: Generated Solidity code for the updates
 * @throws {Error} If any step in the process fails
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
        /**
         * Chain details fetched from CSV containing network information
         * @type {Array<{name: string, chainId: string, recoveryAddress: string}>}
         */
        const chainDetails = await getChainDetailsFromCSV(
            CHAIN_DETAILS_SHEET_URL,
        );

        // 1. Download and parse CSV
        console.warn("Downloading contracts in scope CSV...");
        /**
         * Normalized contract state from CSV
         * @type {{[chainId: string]: Array<{accountAddress: string, childContractScope: number}>}}
         */
        const csvState = await getNormalizedContractsInScopeFromCSV(
            CONTRACTS_IN_SCOPE_SHEET_URL,
        );

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        /**
         * Normalized on-chain state for contracts
         * @type {{[chainId: string]: Array<{accountAddress: string, childContractScope: number}>}}
         */
        const onChainState = await getNormalizedDataFromOnchainState(
            agreementContract,
            chainDetails,
        );

        // 3. Generate updates
        console.warn("Generating updates...");
        /**
         * Array of update objects representing differences between CSV and on-chain state
         * @type {Array<{function: string, args: Array<any>, calldata: string}>}
         */
        const updates = generateUpdates(onChainState, csvState, chainDetails);

        if (updates.length === 0) {
            return {
                updates: [],
                solidityCode: "",
            };
        }

        // 4. Generate solidity code
        /**
         * Generated Solidity code for the updates
         * @type {string}
         */
        const solidityCode = generateSolidityCode(updates);

        return {
            updates,
            solidityCode,
        };
    } catch (error) {
        /**
         * Error object caught during payload generation
         * @type {Error}
         */
        console.error("Error generating update payload:", error);
        throw error;
    }
}
