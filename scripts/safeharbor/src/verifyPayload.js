import { generatePayload } from "./generatePayload.js";

// Main verification function
export async function verifyPayload(calldata, agreementContract) {
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
        let { wrappedUpdates } = await generatePayload(agreementContract);

        if (!wrappedUpdates) {
            wrappedUpdates = { calldata: "0x" };
        }

        // 2. Compare the calldata with expected updates
        console.warn("\nComparing calldata with expected updates...");
        const comparisonResult = wrappedUpdates.calldata === calldata;

        return {
            success: comparisonResult,
            wrappedUpdates: wrappedUpdates.calldata,
            providedUpdates: calldata,
        };
    } catch (error) {
        console.error("Failed to verify calldata:", error);
        throw error;
    }
}
