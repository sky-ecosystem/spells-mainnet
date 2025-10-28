import "dotenv/config";
import { generatePayload } from "./src/generatePayload.js";

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

// Execute based on command
try {
    if (command === "generate" || !command) {
        // Default to generate if no command or explicit generate command
        /**
         * Result object containing updates and generated Solidity code
         * @type {{updates: Array<{function: string, args: Array<any>, calldata: string}>, solidityCode: string}}
         */
        const result = await generatePayload(agreementContract);

        if (result.updates && result.updates.length > 0) {
            console.log(result.solidityCode);
            console.warn("Payload generation completed successfully.");
            process.exit(0);
        } else {
            console.warn("No updates to generate");
            process.exit(0);
        }
    } else if (command === "inspect") {
        const result = await generatePayload(agreementContract);

        if (result.updates && result.updates.length > 0) {
            console.log(JSON.stringify(result, null, 2));
            console.warn("Payload generation completed successfully.");
            process.exit(0);
        } else {
            console.warn("No updates to generate");
            process.exit(0);
        }
    } else {
        console.error(`Error: Unknown command '${command}'`);
        console.error("Available commands: generate, inspect");
        console.error("Usage: npm run generate");
        process.exit(1);
    }
} catch (error) {
    console.error("Failed to execute command:", error);
    process.exit(1);
}
