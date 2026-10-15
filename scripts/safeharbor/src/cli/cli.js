import { JsonRpcProvider } from "ethers";
import { createAgreementReader, encodeUpdates } from "../agreement/index.js";
import { DIAGNOSTIC_CODES as $, formatDiagnostic } from "../diagnostic/index.js";
import { generateSolidity } from "../generation/index.js";
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
            result.warnings.forEach((diagnostic) => console.warn(formatCliMessage("⚠️", formatDiagnostic(diagnostic))));
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

function generate({ changes, warnings }) {
    if (warnings.length > 0) {
        console.warn(`❌ Payload generation blocked: ${warnings.length} validation warning(s).`);
        return 2;
    }

    if (changes.length === 0) {
        console.warn("✅ No updates to generate");
        return 0;
    }

    console.log(generateSolidity(encodeUpdates(changes)));
    console.warn("✅ Payload generation completed successfully.");
    return 0;
}

function inspect(report) {
    console.log(JSON.stringify(report, (_key, value) => (typeof value === "bigint" ? value.toString() : value), 2));
    return 0;
}

function verify({ changes, warnings }) {
    if (changes.length === 0 && warnings.length === 0) {
        console.log("✅ SafeHarbor verification passed: no updates or validation warnings.");
        return 0;
    }

    console.log(
        `❌ SafeHarbor verification failed: ${changes.length} update(s), ${warnings.length} validation warning(s).`,
    );
    return 2;
}

const COMMANDS = { generate, inspect, verify };
