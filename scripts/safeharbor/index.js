import "dotenv/config";
import { JsonRpcProvider } from "ethers";
import { createAgreementReader } from "./src/agreement.js";
import { createCommandRunner, reportError } from "./src/cli.js";
import { validateOptions } from "./src/validateOptions.js";
import { formatDiagnostic } from "./src/formatDiagnostic.js";
import { createPayloadGenerator } from "./src/generatePayload.js";

async function main() {
    const command = process.argv[2];
    const rpcUrl = process.env.ETH_RPC_URL;
    const diagnostics = validateOptions({ command, rpcUrl });
    if (diagnostics.length > 0) {
        diagnostics.forEach((diagnostic) =>
            console.error(formatDiagnostic(diagnostic)),
        );
        return 1;
    }

    try {
        const provider = new JsonRpcProvider(rpcUrl);
        try {
            const getAgreementDetails = createAgreementReader({ provider });
            const generatePayload = createPayloadGenerator({
                getAgreementDetails,
            });
            const runCommand = createCommandRunner({ generatePayload });
            return await runCommand(command);
        } finally {
            provider.destroy();
        }
    } catch (error) {
        reportError(error);
        return 1;
    }
}

process.exitCode = await main();
