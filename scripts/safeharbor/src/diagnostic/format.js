import { formatList } from "../utils/formatList.js";
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
        duplicateHeaders: formatList(context.duplicateHeaders),
    }),
    [$.INVALID_EVM_RECOVERY_ADDRESS]: (context) => ({
        onChainRecoveryAddress: context.isNewChain ? "not registered" : context.onChainRecoveryAddress,
    }),
    [$.INCOMPLETE_CHAIN_METADATA]: (context) => ({
        missingFields: formatList(context.missingFields),
    }),
    [$.MISSING_SHEET_HEADERS]: (context) => ({
        missingHeaders: formatList(context.missingHeaders),
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
