import { JsonRpcProvider } from "ethers";
import { formatDiagnostic } from "../diagnostic/index.js";
import { createAgreementReader } from "../agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../sheet/index.js";
import { reconcile } from "../reconciliation/index.js";
import { COMMANDS } from "./commands/index.js";
import { formatCliMessage, formatOperationalError } from "./format.js";
import { validateOptions } from "./validate.js";

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
