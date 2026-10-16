import { escapeTerminalControlCharacters } from "../utils/controlCharacters.js";
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
    return escapeTerminalControlCharacters(JSON.stringify(value));
}

function renderTemplate(template, values) {
    return template.replace(/\{(\w+)\}/g, (_, key) => {
        if (values[key] === undefined) {
            throw new Error(`Missing template value: ${key}`);
        }
        return String(values[key]);
    });
}
