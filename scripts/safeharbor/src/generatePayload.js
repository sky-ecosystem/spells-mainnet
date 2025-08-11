import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";

// Constants
import { CSV_URL_SHEET1 } from "./constants.js";

/**
 * Orchestrates creation of an update payload by combining CSV data with on-chain state.
 *
 * Downloads and normalizes data from a Google Sheet CSV, fetches normalized on-chain state,
 * then computes and returns the updates produced by `generateUpdates`.
 *
 * @returns {Object|Array} The generated updates payload (structure depends on `generateUpdates`).
 * @throws {Error} If downloading the CSV, fetching on-chain state, or generating updates fails.
 */
export async function generatePayload() {
    try {
        // 1. Download and parse CSV
        console.warn("Downloading Google Sheet CSV...");
        const csvState = await getNormalizedDataFromCSV(CSV_URL_SHEET1);

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        const onChainState = await getNormalizedDataFromOnchainState();

        // 3. Generate updates
        const updates = generateUpdates(onChainState, csvState);

        console.log(JSON.stringify(updates, null, 2));
        return updates;
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
