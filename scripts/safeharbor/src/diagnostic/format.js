import { DIAGNOSTIC_CODES as $ } from "./codes.js";
import { diagnosticTemplates } from "./templates.js";

export function formatDiagnostic({ code, context = {} }) {
    return renderTemplate(diagnosticTemplates[code], {
        ...context,
        ...formatContext[code]?.(context),
    });
}

const formatContext = {
    [$.DUPLICATE_SHEET_HEADERS]: (context) => ({
        duplicateHeaders: context.duplicateHeaders.join(", "),
    }),
    [$.INVALID_EVM_RECOVERY_ADDRESS]: (context) => ({
        onChainRecoveryAddress: context.isNewChain
            ? "not registered"
            : context.onChainRecoveryAddress,
    }),
    [$.INCOMPLETE_CHAIN_METADATA]: (context) => ({
        missingFields: context.missingFields.join(", "),
    }),
    [$.MISSING_SHEET_HEADERS]: (context) => ({
        missingHeaders: context.missingHeaders.join(", "),
    }),
    [$.INVALID_NEW_CHAIN_ACCOUNTS]: (context) => ({
        accounts: JSON.stringify(context.accounts, (_key, value) =>
            typeof value === "bigint" ? value.toString() : value,
        ),
    }),
};

function renderTemplate(template, values) {
    return template.replace(/\{(\w+)\}/g, (_, key) => {
        if (values[key] === undefined) {
            throw new Error(`Missing template value: ${key}`);
        }
        return String(values[key]);
    });
}
