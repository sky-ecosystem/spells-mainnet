import "dotenv/config";
import { generatePayload } from "./src/generatePayload.js";
import { inspectPayload } from "./src/inspectPayload.js";
import { verifyPayload } from "./src/verifyPayload.js";

import { CONTRACTS_IN_SCOPE_SHEET_URL, CHAIN_DETAILS_SHEET_URL } from "./src/constants.js";
import { createAgreementInstance } from "./src/utils/contractUtils.js";

// Check if ETH_RPC_URL is set
if (!process.env.ETH_RPC_URL) {
    console.error("Error: ETH_RPC_URL environment variable is not set.");
    console.error(
        "Please set your Ethereum RPC URL in a .env file or as an environment variable.",
    );
    console.error(
        "Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
    );
    process.exit(1);
}

// Create agreement contract instance
const agreementContract = createAgreementInstance(process.env.ETH_RPC_URL);

// Get command and arguments
const command = process.argv[2];
const calldata = process.argv[3];

// Execute based on command
try {
    if (command === "verify") {
        if (!calldata) {
            console.error(
                "Error: Calldata argument is required for verify command.",
            );
            console.error("Usage: npm run verify <calldata>");
            console.error("Example: npm run verify 0x252dba42000000000...");
            process.exit(1);
        }

        const result = await verifyPayload(
            calldata,
            CONTRACTS_IN_SCOPE_SHEET_URL,
            CHAIN_DETAILS_SHEET_URL,
            agreementContract,
        );

        if (result.success) {
            console.log("✅ VERIFICATION PASSED");
        } else {
            console.log("❌ VERIFICATION FAILED");

            // Show the calldatas for comparison
            console.log("\nExpected calldata:");
            console.log(result.expectedUpdates);
            console.log("\nProvided calldata:");
            console.log(result.providedUpdates);
        }

        process.exit(result.success ? 0 : 1);
    } else if (command === "generate" || !command) {
        // Default to generate if no command or explicit generate command
        const multicallUpdates = await generatePayload({
            contractsInScopeUrl: CONTRACTS_IN_SCOPE_SHEET_URL,
            chainDetailsUrl: CHAIN_DETAILS_SHEET_URL,
            agreementContract: agreementContract,
        });

        if (multicallUpdates) {
            console.log(JSON.stringify(multicallUpdates, null, 2));
            console.warn("Payload generation completed successfully.");
            process.exit(0);
        } else {
            console.error("No updates to generate");
            process.exit(1);
        }
    } else if (command === "inspect") {
        const multicallUpdates = await inspectPayload({
            contractsInScopeUrl: CONTRACTS_IN_SCOPE_SHEET_URL,
            chainDetailsUrl: CHAIN_DETAILS_SHEET_URL,
            agreementContract: agreementContract,
        });

        if (multicallUpdates) {
            console.log(JSON.stringify(multicallUpdates, null, 2));
            console.warn("Payload generation completed successfully.");
            process.exit(0);
        } else {
            console.error("No updates to generate");
            process.exit(1);
        }
    } else {
        console.error(`Error: Unknown command '${command}'`);
        console.error("Available commands: generate, verify");
        console.error("Usage: npm run generate");
        console.error("Usage: npm run verify <calldata>");
        process.exit(1);
    }
} catch (error) {
    console.error("Failed to execute command:", error);
    process.exit(1);
}
