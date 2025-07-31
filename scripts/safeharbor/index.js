import "dotenv/config";
import { generatePayload } from "./src/generatePayload.js";

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

// Execute the main function
try {
    await generatePayload();
    console.log("Payload generation completed successfully.");
    process.exit(0);
} catch (error) {
    console.error("Failed to generate payload:", error);
    process.exit(1);
}
