import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { parse } from "csv-parse/sync";

export async function downloadAndParse(url) {
    const response = await fetch(url);
    if (!response.ok) {
        const diagnostic = {
            code: $.HTTP_ERROR,
            context: { status: response.status },
        };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    if (!response.headers.get("content-type")?.includes("text/csv")) {
        const diagnostic = { code: $.INVALID_CSV_CONTENT_TYPE };
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    let headers = [];
    const records = parse(await response.text(), {
        columns: (columns) => {
            headers = columns;
            return columns;
        },
        skip_empty_lines: true,
        trim: true,
    });
    return { headers, records };
}
