import { parse } from "csv-parse/sync";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { findDuplicateIndexes } from "../utils/findDuplicateIndexes.js";

export async function downloadAndParse(url) {
    const response = await fetch(url);
    if (!response.ok) {
        const diagnostic = {
            code: $.HTTP_ERROR,
            context: { status: response.status },
        };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    if (
        response.headers
            .get("content-type")
            ?.split(";")[0]
            .trim()
            .toLowerCase() !== "text/csv"
    ) {
        const diagnostic = { code: $.INVALID_CSV_CONTENT_TYPE };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    let headers = [];
    const records = parse(await response.text(), {
        columns: (columns) => {
            assertUniqueHeaders(columns);
            headers = columns;
            return columns;
        },
        skip_empty_lines: true,
        trim: true,
    });
    return { headers, records };
}

function assertUniqueHeaders(headers) {
    const duplicateHeaders = [...findDuplicateIndexes(headers)].map(
        (index) => headers[index],
    );
    if (duplicateHeaders.length === 0) {
        return;
    }
    const diagnostic = {
        code: $.DUPLICATE_SHEET_HEADERS,
        context: { duplicateHeaders },
    };
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}
