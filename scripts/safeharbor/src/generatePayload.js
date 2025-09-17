import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { wrapWithMulticall } from "./utils/multicallWrapper.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

/**
 * Orchestrates CSV download, on-chain state fetch, and update generation, returning a multicall-wrapped payload.
 *
 * The function downloads and normalizes CSV data, fetches the current on-chain state for the provided agreement,
 * computes required updates, and wraps them for a multicall execution. If no updates are required, it returns undefined.
 *
 * @param {Object} params - Function parameters.
 * @param {string} params.csvUrl - URL of the CSV (e.g., a Google Sheet CSV export) to download and normalize.
 * @returns {Array|undefined} An array of multicall-wrapped update transactions, or `undefined` when there are no updates.
 * @throws {Error} Rethrows errors encountered while downloading/parsing the CSV, fetching on-chain state, or generating/wrapping updates.
 */
export async function generatePayload({ csvUrl, agreementContract }) {
    try {
        // 1. Download and parse CSV
        console.warn("Downloading Google Sheet CSV...");
        const csvState = await getNormalizedDataFromCSV(csvUrl);

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        const onChainState =
            await getNormalizedDataFromOnchainState(agreementContract);

        // 3. Generate updates
        console.warn("Generating updates...");
        const updates = generateUpdates(onChainState, csvState);

        if (updates.length === 0) {
            return;
        }

        // 4. Wrap with multicall
        console.warn("Wrapping with multicall...");
        const wrappedUpdates = wrapWithMulticall(
            updates,
            AGREEMENT_ADDRESS,
            MULTICALL_ADDRESS,
        );

        return wrappedUpdates;
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
