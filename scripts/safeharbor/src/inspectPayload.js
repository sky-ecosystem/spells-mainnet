import {
    getChainDetailsFromCSV,
    getNormalizedContractsInScopeFromCSV,
} from "./fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "./fetchOnchain.js";
import { generateUpdates } from "./generateUpdates.js";
import { wrapWithMulticall } from "./utils/multicallWrapper.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "./constants.js";

// Main function
export async function inspectPayload({
    contractsInScopeUrl,
    chainDetailsUrl,
    agreementContract,
    inspect = false,
}) {
    try {
        // 0. Fetch chain information once at the beginning
        console.warn("Fetching chain information...");
        const chainDetails = await getChainDetailsFromCSV(chainDetailsUrl);

        // 1. Download and parse CSV
        console.warn("Downloading Google Sheet CSV...");
        const csvState =
            await getNormalizedContractsInScopeFromCSV(contractsInScopeUrl);

        // 2. Fetch on-chain state
        console.warn("Fetching on-chain state...");
        const onChainState = await getNormalizedDataFromOnchainState(
            agreementContract,
            chainDetails,
        );

        // 3. Generate updates
        console.warn("Generating updates...");
        const updates = generateUpdates(onChainState, csvState, chainDetails);

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
            chainDetails,
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
