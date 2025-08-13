import "dotenv/config";
import { generatePayload } from "./generatePayload.js";

// Validate calldata format
function validateCalldata(calldata) {
    if (!calldata.startsWith("0x")) {
        console.error("Error: Invalid calldata format, must start with '0x' ");
        process.exit(1);
    }
}

// Main verification function
export async function verifyPayload(calldata) {
    // Validate calldata format
    validateCalldata(calldata);

    // Execute the verification
    try {
        console.warn("Starting calldata verification...");
        console.warn(`Calldata to verify: ${calldata}\n`);

        // 1. Generate expected updates (same as generate script)
        console.warn("Generating expected updates...");
        const expectedUpdates = await generatePayload();

        // 2. Compare the calldata with expected updates
        console.warn("\nComparing calldata with expected updates...");
        const comparisonResult = expectedUpdates[expectedUpdates.length - 1].calldata === calldata;

        if (comparisonResult) {
            console.log("✅ VERIFICATION PASSED");
        } else {
            console.log("❌ VERIFICATION FAILED");

            // Show the calldatas for comparison
            console.log("\nExpected calldata:");
            console.log(expectedUpdates[expectedUpdates.length - 1].calldata);
            console.log("\nProvided calldata:");
            console.log(calldata);
        }
        return comparisonResult;
    } catch (error) {
        console.error("Failed to verify calldata:", error);
        throw error;
    }
}
