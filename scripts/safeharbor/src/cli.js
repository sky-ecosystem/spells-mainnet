import { DIAGNOSTIC_CODES as $ } from "./diagnosticCodes.js";
import { formatDiagnostic } from "./formatDiagnostic.js";

export function createCommandRunner({ generatePayload }) {
    return async function runCommand(command) {
        try {
            const result = await generatePayload();
            result.validationWarnings.forEach((diagnostic) =>
                console.warn(formatDiagnostic(diagnostic)),
            );
            const warningCount = result.validationWarnings.length;

            if (command === "generate") {
                if (warningCount > 0) {
                    console.warn(
                        `Payload generation blocked: ${warningCount} validation warning(s).`,
                    );
                    return 2;
                }

                if (result.updates.length > 0) {
                    console.log(result.solidityCode);
                }

                console.warn(
                    result.updates.length > 0
                        ? "Payload generation completed successfully."
                        : "No updates to generate",
                );
                return 0;
            }

            if (command === "inspect") {
                console.log(JSON.stringify(result, null, 2));
                return 0;
            }

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
            reportError(error);
            return 1;
        }
    };
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
    if (!COMMANDS.has(command)) {
        return [{ code: $.UNKNOWN_COMMAND, context: { command } }];
    }
    return rpcUrl ? [] : [{ code: $.RPC_URL_REQUIRED }];
}

const COMMANDS = new Set(["generate", "inspect", "verify"]);
