import "dotenv/config";
import { generatePayload } from "./src/generatePayload.js";
import { verifyPayload } from "./src/verifyPayload.js";

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

// Get command and arguments
const command = process.argv[2];
const calldata = process.argv[3];

// Execute based on command
try {
    if (command === "verify") {
        if (!calldata) {
            console.error("Error: Calldata argument is required for verify command.");
            console.error("Usage: npm run verify <calldata>");
            console.error("Example: npm run verify 0x252dba42000000000...");
            process.exit(1);
        }
        
        const result = await verifyPayload(calldata);
        process.exit(result ? 0 : 1);
    } else if (command === "generate" || !command) {
        // Default to generate if no command or explicit generate command
        await generatePayload();
        console.warn("Payload generation completed successfully.");
        process.exit(0);
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
