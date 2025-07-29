import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";

// Constants
import { CSV_URL_SHEET1 } from "./constants.js";

import { writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// Main function
export async function generateUpdatePayload() {
    try {
        // 1. Download and parse CSV
        console.log("Downloading Google Sheet CSV...");
        const csvState = await getNormalizedDataFromCSV(CSV_URL_SHEET1);

        // 2. Fetch on-chain state
        console.log("Fetching on-chain state...");
        const onChainState = await getNormalizedDataFromOnchainState();

        // 3. Generate updates
        const updates = generateUpdates(onChainState, csvState);

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

generateUpdatePayload();
