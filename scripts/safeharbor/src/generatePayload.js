import {
    getChainDetailsFromCSV,
    getNormalizedContractsInScopeFromCSV,
} from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { validateState } from "./validateState.js";
import { generateUpdates } from "./generateUpdates.js";
import { generateSolidityCode } from "./utils/generateSolidity.js";
import {
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "./constants.js";

/**
 * Main function to generate update payload for SafeHarbor agreement
 *
 * This function orchestrates the entire payload generation process:
 * 1. Fetches chain details from CSV
 * 2. Downloads and parses contracts in scope CSV
 * 3. Fetches and normalizes the Agreement's on-chain state
 * 4. Collects validation warnings and stops if any are found
 * 5. Generates updates based on differences and renders Solidity code
 *
 * @async
 * @function generatePayload
 * @param {Object} agreementContract - The ethers.js agreement contract instance
 * @returns {Promise<{updates: Array<{function: string, args: Array<any>, calldata: string}>, solidityCode: string, validationWarnings: string[]}>} Object containing:
 *   - updates: Array of update objects with function calls and calldata; empty on validation warnings
 *   - solidityCode: Generated Solidity code for the updates; empty on validation warnings
 *   - validationWarnings: Warnings from source normalization and state validation
 * @throws {Error} If any step in the process fails
 */
export async function generatePayload(agreementContract) {
    try {
        // 0. Fetch chain information once at the beginning
        console.warn("Fetching chains details CSV...");
        /**
         * Chain details fetched from CSV containing network information
         * @type {{chainDetails: {caip2ChainId: Object<string, string>, assetRecoveryAddress: Object<string, string>, name: Object<string, string>}, validationWarnings: string[]}}
         */
        const { chainDetails, validationWarnings: chainDetailsWarnings } =
            await getChainDetailsFromCSV(CHAIN_DETAILS_SHEET_URL);

        // 1. Download and parse CSV
        console.warn("Downloading contracts in scope CSV...");
        /**
         * Normalized contract state from CSV
         * @type {{[chainName: string]: Array<{accountAddress: string, childContractScope: number}>}}
         */
        const csvState = await getNormalizedContractsInScopeFromCSV(
            CONTRACTS_IN_SCOPE_SHEET_URL,
        );

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        /**
         * Normalized on-chain state keyed by chain name, with source warnings
         * @type {{onChainState: Object<string, {accounts: Array<{accountAddress: string, childContractScope: bigint}>, assetRecoveryAddress: string}>, validationWarnings: string[]}}
         */
        const { onChainState, validationWarnings: onChainWarnings } =
            await getNormalizedDataFromOnchainState(
                agreementContract,
                chainDetails,
            );

        // 3. Collect all warnings before generating executable updates.
        const validationWarnings = [
            ...chainDetailsWarnings,
            ...onChainWarnings,
            ...validateState(onChainState, csvState, chainDetails),
        ];
        validationWarnings.forEach((warning) => console.warn(warning));

        if (validationWarnings.length > 0) {
            return {
                updates: [],
                solidityCode: "",
                validationWarnings,
            };
        }

        // 4. Generate updates and Solidity code.
        console.warn("Generating updates...");
        const updates = generateUpdates(onChainState, csvState, chainDetails);
        /**
         * Generated Solidity code for the updates
         * @type {string}
         */
        const solidityCode = generateSolidityCode(updates);

        return {
            updates,
            solidityCode,
            validationWarnings,
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
