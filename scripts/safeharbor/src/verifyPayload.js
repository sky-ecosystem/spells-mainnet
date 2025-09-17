import { generatePayload } from "./generatePayload.js";

/**
 * Verify that a provided calldata string matches the expected calldata generated from CSV and contract inputs.
 *
 * Validates that `calldata` starts with "0x" (exits the process with code 1 if not), generates the expected payload
 * by calling `generatePayload({ csvUrl, agreementContract })`, and returns true if the generated `expectedUpdates.calldata`
 * strictly equals the provided `calldata`.
 *
 * @param {string} calldata - Hex-encoded calldata to verify; must start with "0x".
 * @param {string} csvUrl - URL or path to the CSV used to build the expected payload.
 * @param {string} agreementContract - Identifier (e.g., address) of the agreement contract used when generating the payload.
 * @returns {Promise<boolean>} Resolves to true if the provided calldata matches the generated calldata, otherwise false.
 * @throws {*} Rethrows any error raised while generating the expected payload.
 */
export async function verifyPayload(calldata, csvUrl, agreementContract) {
    // Validate calldata format
    if (!calldata.startsWith("0x")) {
        console.error("Error: Invalid calldata format, must start with '0x' ");
        process.exit(1);
    }

    // Execute the verification
    try {
        console.warn("Starting calldata verification...");
        console.warn(`Calldata to verify: ${calldata}\n`);

        // 1. Generate expected updates (same as generate script)
        console.warn("Generating expected updates...");
        const expectedUpdates = await generatePayload({
            csvUrl,
            agreementContract,
        });

        // 2. Compare the calldata with expected updates
        console.warn("\nComparing calldata with expected updates...");
        const comparisonResult = expectedUpdates.calldata === calldata;

        return comparisonResult;
    } catch (error) {
        console.error("Failed to verify calldata:", error);
        throw error;
    }
}
