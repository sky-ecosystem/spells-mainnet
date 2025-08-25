import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { wrapWithMulticall } from "./utils/multicallWrapper.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

// Main function
export async function generatePayload({ csvUrl, agreementContract, inspect = false }) {
    try {
        // 1. Download and parse CSV
        console.warn("Downloading Google Sheet CSV...");
        const csvState = await getNormalizedDataFromCSV(csvUrl);

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        const onChainState = await getNormalizedDataFromOnchainState(agreementContract);

        // 3. Generate updates
        console.warn("Generating updates...");
        const updates = generateUpdates(onChainState, csvState);

        // 4. Wrap with multicall
        console.warn("Wrapping with multicall...");
        const wrappedUpdates = wrapWithMulticall(updates, AGREEMENT_ADDRESS, MULTICALL_ADDRESS, inspect);

        return wrappedUpdates;
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
