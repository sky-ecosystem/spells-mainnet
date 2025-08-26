import { getNormalizedDataFromCSV } from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { wrapWithMulticall } from "./utils/multicallWrapper.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

/**
 * Build a sanitized update payload by comparing CSV data with on-chain state and (optionally) wrapping updates in a multicall.
 *
 * Downloads and normalizes CSV data from the provided URL, fetches the normalized on-chain state for the given agreement,
 * generates any required updates, and — if updates exist — produces a multicall wrapper. The returned `updates` array has
 * each update's `calldata` removed to keep the payload human-readable; the full multicall payload (including calldata)
 * is returned as `multicall`.
 *
 * @param {string} csvUrl - URL of the CSV (typically a Google Sheet CSV) to download and normalize.
 * @param {boolean} [inspect=false] - If true, the multicall wrapper may be generated in inspect/debug mode.
 * @returns {{ updates: Array<object>, multicall: object }|undefined} An object containing `updates` (with `calldata` removed) and the full `multicall` payload, or `undefined` if no updates are required.
 * @throws {Error} If CSV download, on-chain fetch, update generation, or multicall wrapping fails; the original error is rethrown.
 */
export async function inspectPayload({
    csvUrl,
    agreementContract,
    inspect = false,
}) {
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

        // Check if object is empty
        if (updates.length === 0) {
            return;
        }

        // 4. Wrap with multicall
        console.warn("Wrapping with multicall...");
        const wrappedUpdates = wrapWithMulticall(
            updates,
            AGREEMENT_ADDRESS,
            MULTICALL_ADDRESS,
            inspect,
        );

        // Remove the inner calldata from the updates to avoid confusion
        const slimUpdates = updates.map((update) => {
            delete update.calldata;
            return update;
        });

        return { updates: slimUpdates, multicall: wrappedUpdates };
    } catch (error) {
        console.error("Error generating update payload:", error);
        throw error;
    }
}
