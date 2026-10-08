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
    [$.SHEET_CHAIN_ID_LINE_TERMINATOR]: ({ chainId }) => ({
        chainId: formatVisibleString(chainId),
    }),
    [$.INVALID_SHEET_HEADER_CONTROL_CHARACTER]: ({ header }) => ({
        header: formatVisibleString(header),
    }),
    [$.INVALID_SHEET_CELL_CONTROL_CHARACTER]: ({ value }) => ({
        value: formatVisibleString(value),
    }),
    [$.DUPLICATE_SHEET_HEADERS]: (context) => ({
        duplicateHeaders: formatList(context.duplicateHeaders),
    }),
    [$.INCOMPLETE_CHAIN_METADATA]: (context) => ({
        missingFields: formatList(context.missingFields),
    }),
    [$.MISSING_SHEET_HEADERS]: (context) => ({
        missingHeaders: formatList(context.missingHeaders),
    }),
};

function formatVisibleString(value) {
    return JSON.stringify(value).replace(
        /[\u0085\u2028\u2029\u202a-\u202e\u2066-\u2069]/g,
        (character) => `\\u${character.charCodeAt(0).toString(16).padStart(4, "0")}`,
    );
}

function renderTemplate(template, values) {
    return template.replace(/\{(\w+)\}/g, (_, key) => {
        if (values[key] === undefined) {
            throw new Error(`Missing template value: ${key}`);
        }
        return String(values[key]);
    });
}
