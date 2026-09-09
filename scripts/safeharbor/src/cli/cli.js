import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { JsonRpcProvider } from "ethers";
import { createAgreementReader } from "../agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../sheet/index.js";
import { formatDiagnostic } from "./formatDiagnostic.js";
import { reconcile } from "../reconciliation/index.js";
import { generate } from "./commands/generate.js";
import { inspect } from "./commands/inspect.js";
import { verify } from "./commands/verify.js";

export async function main() {
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
            const result = await reconcile({
                getAgreementState: createAgreementReader(provider),
                getSheetState,
                getSheetChainDetails,
            });
            result.validationWarnings.forEach((diagnostic) =>
                console.warn(formatDiagnostic(diagnostic)),
            );
            return COMMANDS[command](result);
        } finally {
            provider.destroy();
        }
    } catch (error) {
        reportError(error);
        return 1;
    }
}

function reportError(error) {
    console.error(
        "Failed to execute command:",
        error?.diagnostic
            ? formatDiagnostic(error.diagnostic)
            : (error?.message ?? String(error)),
    );
}

function validateOptions({ command, rpcUrl }) {
    if (!command) {
        return [{ code: $.COMMAND_REQUIRED }];
    }
    if (!Object.hasOwn(COMMANDS, command)) {
        return [{ code: $.UNKNOWN_COMMAND, context: { command } }];
    }
    return rpcUrl ? [] : [{ code: $.RPC_URL_REQUIRED }];
}

const COMMANDS = { generate, inspect, verify };
