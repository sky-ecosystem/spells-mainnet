import { DIAGNOSTIC_CODES as $ } from "./diagnosticCodes.js";
import { JsonRpcProvider } from "ethers";
import { createAgreementReader } from "./agreement.js";
import { formatDiagnostic } from "./formatDiagnostic.js";
import { createReconciler } from "./reconcile.js";
import { generate } from "./generate.js";
import { inspect } from "./inspect.js";
import { verify } from "./verify.js";

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
            const getAgreementDetails = createAgreementReader({ provider });
            const reconcile = createReconciler({
                getAgreementDetails,
            });
            const result = await reconcile();
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

export function reportError(error) {
    console.error(
        "Failed to execute command:",
        error?.diagnostic
            ? formatDiagnostic(error.diagnostic)
            : (error?.message ?? String(error)),
    );
}

export function validateOptions({ command, rpcUrl }) {
    if (!command) return [{ code: $.COMMAND_REQUIRED }];
    if (!Object.hasOwn(COMMANDS, command)) {
        return [{ code: $.UNKNOWN_COMMAND, context: { command } }];
    }
    return rpcUrl ? [] : [{ code: $.RPC_URL_REQUIRED }];
}

const COMMANDS = { generate, inspect, verify };
