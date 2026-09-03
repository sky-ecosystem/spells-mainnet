import { generatePayload } from "./generatePayload.js";
import { testSpell as testSpellCommand } from "./testSpell.js";
import { createAgreementInstance } from "./utils/contractUtils.js";

const COMMANDS = ["generate", "inspect", "verify", "testSpell"];

export async function runCommand(
    command,
    {
        rpcUrl,
        forkBlock,
        port,
        createAgreement = createAgreementInstance,
        generate = generatePayload,
        testSpell = testSpellCommand,
        stdout = console.log,
        stderr = console.error,
        warn = console.warn,
    } = {},
) {
    const selectedCommand = command || "generate";

    if (!COMMANDS.includes(selectedCommand)) {
        stderr(`Error: Unknown command '${selectedCommand}'`);
        stderr(`Available commands: ${COMMANDS.join(", ")}`);
        stderr("Usage: npm run <command>");
        return 1;
    }

    if (!rpcUrl) {
        stderr("Error: ETH_RPC_URL environment variable is not set.");
        stderr(
            "Please set your Ethereum RPC URL in a .env file or as an environment variable.",
        );
        stderr(
            "Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
        );
        return 1;
    }

    try {
        if (selectedCommand === "testSpell") {
            return await testSpell({
                rpcUrl,
                forkBlock,
                port,
                verify: (verificationRpcUrl) =>
                    runCommand("verify", {
                        rpcUrl: verificationRpcUrl,
                        createAgreement,
                        generate,
                        stderr,
                        stdout,
                        warn,
                    }),
            });
        }

        const agreementContract = await createAgreement(rpcUrl);
        const result = await generate(agreementContract);

        if (selectedCommand === "generate") {
            if (result.updates.length > 0) {
                stdout(result.solidityCode);
                warn("Payload generation completed successfully.");
            } else {
                warn("No updates to generate");
            }
            return 0;
        }

        if (selectedCommand === "inspect") {
            stdout(JSON.stringify(result, null, 2));
            if (result.updates.length > 0) {
                warn("Payload generation completed successfully.");
            } else {
                warn("No updates to generate");
            }
            return 0;
        }

        const warningCount = result.validationWarnings.length;
        if (result.updates.length === 0 && warningCount === 0) {
            stdout(
                "SafeHarbor verification passed: no updates or validation warnings.",
            );
            return 0;
        }

        stdout(
            `SafeHarbor verification failed: ${result.updates.length} update(s), ${warningCount} validation warning(s).`,
        );
        return 2;
    } catch (error) {
        // Interrupt is not a failure, return the given exit code instead
        if (
            error?.interrupted &&
            (error.exitCode === 130 || error.exitCode === 143)
        ) {
            return error.exitCode;
        }

        stderr("Failed to execute command:", error);
        return 1;
    }
}
