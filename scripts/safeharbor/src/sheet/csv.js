import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { parse } from "csv-parse/sync";

export async function downloadAndParse(url) {
    const response = await fetch(url);
    const diagnostic = !response.ok
        ? {
              code: $.HTTP_ERROR,
              context: { status: response.status },
          }
        : !response.headers.get("content-type")?.includes("text/csv")
          ? { code: $.INVALID_CSV_CONTENT_TYPE }
          : undefined;
    if (diagnostic) {
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
    const csvText = await response.text();
    let headers = [];
    const records = parse(csvText, {
        columns: (columns) => {
            headers = columns;
            return columns;
        },
        skip_empty_lines: true,
        trim: true,
    });
    return { headers, records };
}
