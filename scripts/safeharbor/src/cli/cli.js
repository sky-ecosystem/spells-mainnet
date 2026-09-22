import { JsonRpcProvider } from "ethers";
import { createAgreementReader } from "../agreement/index.js";
import { DIAGNOSTIC_CODES as $, formatDiagnostic } from "../diagnostic/index.js";
import { generatePayload } from "../generation/index.js";
import { reconcile } from "../reconciliation/index.js";
import { getSheetChainDetails, getSheetState } from "../sheet/index.js";
import { formatCliMessage, formatOperationalError } from "./format.js";

export async function main() {
    const command = process.argv[2];
    const rpcUrl = process.env.ETH_RPC_URL;
    const diagnostics = validateOptions({ command, rpcUrl });
    if (diagnostics.length > 0) {
        diagnostics.forEach((diagnostic) => console.error(formatCliMessage("❌", formatDiagnostic(diagnostic))));
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
                console.warn(formatCliMessage("⚠️", formatDiagnostic(diagnostic))),
            );
            return COMMANDS[command](result);
        } finally {
            provider.destroy();
        }
    } catch (error) {
        console.error(formatCliMessage("❌", formatOperationalError(error)));
        return 1;
    }
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

function generate(report) {
    const warningCount = report.validationWarnings.length;
    if (warningCount > 0) {
        console.warn(`❌ Payload generation blocked: ${warningCount} validation warning(s).`);
        return 2;
    }

    const { updates, solidityCode } = generatePayload(report.changes);
    if (updates.length > 0) {
        console.log(solidityCode);
    }
    console.warn(updates.length > 0 ? "✅ Payload generation completed successfully." : "✅ No updates to generate");
    return 0;
}

function inspect(report) {
    console.log(JSON.stringify(report, (_key, value) => (typeof value === "bigint" ? value.toString() : value), 2));
    return 0;
}

function verify(report) {
    const updateCount = report.changes.length;
    const warningCount = report.validationWarnings.length;
    if (updateCount === 0 && warningCount === 0) {
        console.log("✅ SafeHarbor verification passed: no updates or validation warnings.");
        return 0;
    }

    console.log(`❌ SafeHarbor verification failed: ${updateCount} update(s), ${warningCount} validation warning(s).`);
    return 2;
}

const COMMANDS = { generate, inspect, verify };
