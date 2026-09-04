import { generatePayload } from "./generatePayload.js";
import { createAgreementInstance } from "./utils/contractUtils.js";

const COMMANDS = new Set(["generate", "inspect", "verify"]);

export async function runCommand(command) {
    const selectedCommand = command || "generate";

    if (!COMMANDS.has(selectedCommand)) {
        console.error(`Error: Unknown command '${selectedCommand}'`);
        console.error("Available commands: generate, inspect, verify");
        console.error("Usage: npm run <command>");
        return 1;
    }

    const rpcUrl = process.env.ETH_RPC_URL;
    if (!rpcUrl) {
        console.error("Error: ETH_RPC_URL environment variable is not set.");
        console.error(
            "Please set your Ethereum RPC URL in a .env file or as an environment variable.",
        );
        console.error(
            "Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
        );
        return 1;
    }

    try {
        const agreementContract = await createAgreementInstance(rpcUrl);
        const result = await generatePayload(agreementContract);

        if (selectedCommand === "generate" && result.updates.length > 0) {
            console.log(result.solidityCode);
        }

        if (selectedCommand === "inspect") {
            console.log(JSON.stringify(result, null, 2));
        }

        if (selectedCommand !== "verify") {
            console.warn(
                result.updates.length > 0
                    ? "Payload generation completed successfully."
                    : "No updates to generate",
            );
            return 0;
        }

        const warningCount = result.validationWarnings.length;
        if (result.updates.length === 0 && warningCount === 0) {
            console.log(
                "SafeHarbor verification passed: no updates or validation warnings.",
            );
            return 0;
        }

        console.log(
            `SafeHarbor verification failed: ${result.updates.length} update(s), ${warningCount} validation warning(s).`,
        );
        return 2;
    } catch (error) {
        console.error("Failed to execute command:", error);
        return 1;
    }
}
