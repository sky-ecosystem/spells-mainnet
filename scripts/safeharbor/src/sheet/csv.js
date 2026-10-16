import { parse } from "csv-parse/sync";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { hasUnsafeControlCharacter } from "../utils/controlCharacters.js";
import { findDuplicateIndexes } from "../utils/findDuplicateIndexes.js";
import { CHAIN_DETAILS_HEADERS, CONTRACT_HEADERS } from "./normalize.js";

export async function downloadAndParse(url) {
    const response = await fetch(url);
    if (!response.ok) {
        const diagnostic = {
            code: $.HTTP_ERROR,
            context: { status: response.status },
        };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    if (response.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "text/csv") {
        const diagnostic = { code: $.INVALID_CSV_CONTENT_TYPE };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    let headers = [];
    const records = parse(await response.text(), {
        columns: (columns) => {
            assertNoUnsafeHeaderCharacters(columns);
            assertUniqueHeaders(columns);
            headers = columns;
            return columns;
        },
        skip_empty_lines: true,
        trim: true,
    });
    assertNoUnsafeCellCharacters(records);
    return { headers, records };
}

function assertNoUnsafeHeaderCharacters(headers) {
    const header = headers.find((value) => hasUnsafeControlCharacter(value));
    if (!header) {
        return;
    }
    const diagnostic = {
        code: $.INVALID_SHEET_HEADER_CONTROL_CHARACTER,
        context: { header },
    };
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}

function assertNoUnsafeCellCharacters(records) {
    for (const record of records) {
        for (const [header, value] of Object.entries(record)) {
            const isKnownHeader = CONTRACT_HEADERS.includes(header) || CHAIN_DETAILS_HEADERS.includes(header);
            if (!isKnownHeader || !hasUnsafeControlCharacter(value)) {
                continue;
            }
            const diagnostic = {
                code: $.INVALID_SHEET_CELL_CONTROL_CHARACTER,
                context: { header, value },
            };
            throw Object.assign(new Error(diagnostic.code), { diagnostic });
        }
    }
}

function assertUniqueHeaders(headers) {
    const duplicateHeaders = [...findDuplicateIndexes(headers)].map((index) => headers[index]);
    if (duplicateHeaders.length === 0) {
        return;
    }
    const diagnostic = {
        code: $.DUPLICATE_SHEET_HEADERS,
        context: { duplicateHeaders },
    };
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}
