import "dotenv/config";
import { generatePayload } from "./src/generatePayload.js";
import { parseCalldata } from "./src/parseCalldata.js";

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

// Get calldata from command line arguments
const calldata = process.argv[2];
if (!calldata) {
    console.error("Error: Calldata argument is required.");
    console.error("Usage: npm run verify <calldata>");
    console.error("Example: npm run verify 0x252dba42000000000...");
    process.exit(1);
}

// Validate calldata format
if (!calldata.startsWith('0x') || calldata.length < 10) {
    console.error("Error: Invalid calldata format. Must start with '0x' and be at least 10 characters long.");
    process.exit(1);
}

// Execute the verification
try {
    console.log("Starting calldata verification...");
    console.log(`Calldata to verify: ${calldata}\n`);
    
    // 1. Generate expected updates (same as generate script)
    console.log("Generating expected updates...");
    const expectedUpdates = await generatePayload();
    
    // 2. Compare the calldata with expected updates
    console.log("\nComparing calldata with expected updates...");
    const comparisonResult = expectedUpdates.calldata === calldata;
    
    // 4. Display results
    console.log("VERIFICATION RESULTS");

    if (comparisonResult) {
        console.log("✅ VERIFICATION PASSED");
        console.log("The provided calldata matches the expected updates.");
    } else {
        console.log("❌ VERIFICATION FAILED");
        console.log("The provided calldata does NOT match the expected updates.");
        
        // Show the calldatas for comparison
        console.log("\nExpected calldata:");
        console.log(expectedUpdates.calldata);
        console.log("\nProvided calldata:");
        console.log(calldata);

    }
    
    process.exit(comparisonResult ? 0 : 1);
} catch (error) {
    console.error("Failed to verify calldata:", error);
    process.exit(1);
}
