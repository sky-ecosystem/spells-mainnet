import { JsonRpcProvider } from "ethers";
import {
    DIAGNOSTIC_CODES as $,
    formatDiagnostic,
} from "../diagnostic/index.js";
import { createAgreementReader } from "../agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../sheet/index.js";
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
            console.error(
                `❌ ${formatDiagnostic(diagnostic).replaceAll("\n", "\n       ")}`,
            ),
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
                console.warn(
                    `⚠️ ${formatDiagnostic(diagnostic).replaceAll("\n", "\n       ")}`,
                ),
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
    const source = Object.hasOwn(ERROR_SOURCES, error?.source)
        ? ERROR_SOURCES[error.source]
        : undefined;
    const details = [
        ...(source ? [`Source: ${source}`] : []),
        error?.diagnostic
            ? formatDiagnostic(error.diagnostic)
            : String(error?.message ?? error),
        ...formatErrorCodes(source ? error.cause : error),
    ].join("\n");

    console.error(
        `❌ Failed to execute command:\n       ${details.replaceAll("\n", "\n       ")}`,
    );
}

function formatErrorCodes(error) {
    const lines = [];
    const seen = new Set();
    let indentation = 0;
    for (
        let current = error;
        current && !seen.has(current);
        current = current.cause
    ) {
        seen.add(current);
        if (
            typeof current.code !== "string" ||
            !/^[A-Z][A-Z0-9_]*$/.test(current.code)
        ) {
            continue;
        }
        if (current === error) {
            lines.push(`Code: ${current.code}`);
        } else {
            indentation += 4;
            lines.push(`${" ".repeat(indentation)}Cause: ${current.code}`);
        }
    }
    return lines;
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

const ERROR_SOURCES = {
    sheetChainDetails: "Safeharbor Sheet chain metadata",
    sheetState: "Safeharbor Sheet contracts",
    agreementOnChainState: "Agreement state",
};
