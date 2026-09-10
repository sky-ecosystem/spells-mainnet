import { formatDiagnostic } from "../diagnostic/index.js";

export function formatCliMessage(icon, message) {
    return `${icon} ${message.replaceAll("\n", "\n       ")}`;
}

export function formatOperationalError(error) {
    const source = ERROR_SOURCES[error?.source];
    return [
        "Failed to execute command:",
        ...(source ? [`Source: ${source}`] : []),
        error?.diagnostic
            ? formatDiagnostic(error.diagnostic)
            : String(error?.message ?? error),
        ...formatErrorCodes(source ? error.cause : error),
    ].join("\n");
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

const ERROR_SOURCES = {
    sheetChainDetails: "Safeharbor Sheet chain metadata",
    sheetState: "Safeharbor Sheet contracts",
    agreementOnChainState: "Agreement state",
};
