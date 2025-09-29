import {
    getChainDetailsFromCSV,
    getNormalizedContractsInScopeFromCSV,
} from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { wrapWithMulticall } from "./utils/multicallWrapper.js";
import {
    CONTRACTS_IN_SCOPE_SHEET_URL,
    CHAIN_DETAILS_SHEET_URL,
} from "./constants.js";

// Main function
export async function generatePayload(agreementContract, returnUpdates = false) {
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
            return;
        }

        // 4. Wrap with multicall
        console.warn("Wrapping with multicall...");
        const wrappedUpdates = wrapWithMulticall(updates);

        if (returnUpdates) {
            return {
                updates,
                wrappedUpdates,
            };
        } else {
            return wrappedUpdates;
        }

    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
