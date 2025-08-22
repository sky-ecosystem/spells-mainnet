import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";

// Constants
import { CSV_URL_SHEET1 } from "./constants.js";

// Main function
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
