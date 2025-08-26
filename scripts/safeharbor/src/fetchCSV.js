import { parse } from "csv-parse/sync";

/**
 * Fetches CSV data from the provided URL, validates that the response is CSV, parses it, and returns records.
 *
 * @param {string} url - URL pointing to a CSV resource (e.g. a direct CSV file or a Google Sheets export URL).
 * @return {Array<Object>} Parsed records (each row as an object with column names as keys).
 * @throws {Error} If the HTTP response is not OK (non-2xx status).
 * @throws {Error} If the response content-type does not include "text/csv".
 * @throws {Error} If fetching or parsing fails; the original error is rethrown.
 */
async function downloadAndParse(url) {
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const csvText = await response.text();

        // Basic validation that we got CSV data
        if (!response.headers.get("content-type")?.includes("text/csv")) {
            throw new Error(
                "Invalid content type. Expected CSV data. Please check the URL format.",
            );
        }

        return parse(csvText, {
            columns: true,
            skip_empty_lines: true,
            trim: true,
        });
    } catch (error) {
        console.error("Error downloading CSV:", error.message);
        if (error.message.includes("HTML")) {
            console.error(
                "\nThe URL might be incorrect. For Google Sheets, make sure to use the export URL format:",
            );
            console.error(
                "https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/export?format=csv&gid={SHEET_ID}",
            );
        }
        throw error;
    }
}

/**
 * Group active CSV records by chain and map them to account entries.
 *
 * Filters input records to those with Status === "ACTIVE", groups them by the `Chain` field,
 * and maps each record to an entry with `accountAddress` taken from `Address` and
 * `childContractScope` set to 2 when the record indicates a factory, otherwise 0.
 *
 * @param {Array<Object>} records - Parsed CSV rows. Each record is expected to include:
 *   - `Status` (string): record status, e.g., "ACTIVE".
 *   - `Chain` (string): chain identifier used as the grouping key.
 *   - `Address` (string): account address to emit as `accountAddress`.
 *   - `isFactory` or `IsFactory` (string, optional): may be "TRUE" to mark factory records.
 * @returns {Object<string, Array<{accountAddress: string, childContractScope: number}>>}
 *   An object keyed by chain, each value is an array of mapped account entries.
 */
function normalize(records) {
    return records
        .filter((record) => record.Status === "ACTIVE")
        .reduce((groups, record) => {
            const chain = record.Chain;
            if (!groups[chain]) {
                groups[chain] = [];
            }

            // Handle both possible column names for factory flag
            const isFactory =
                record.isFactory === "TRUE" || record.IsFactory === "TRUE";

            groups[chain].push({
                accountAddress: record.Address,
                childContractScope: isFactory ? 2 : 0,
            });
            return groups;
        }, {});
}

/**
 * Fetches a CSV from the given URL, parses it, and returns normalized records grouped by chain.
 *
 * The CSV is parsed with header columns; only rows with `Status === "ACTIVE"` are kept.
 * Records are grouped by their `Chain` value and mapped to objects with:
 * - `accountAddress`: taken from the `Address` field
 * - `childContractScope`: `2` if the row indicates a factory (`isFactory` or `IsFactory === "TRUE"`), otherwise `0`
 *
 * @param {string} url - URL of the CSV file to fetch and parse.
 * @returns {Promise<Object<string, Array<{accountAddress: string, childContractScope: number}>>>} A promise resolving to an object keyed by chain containing arrays of normalized records.
 * @throws Propagates errors from fetching or parsing the CSV (e.g., non-OK HTTP responses or invalid content).
 */
export async function getNormalizedDataFromCSV(url) {
    const records = await downloadAndParse(url);
    return normalize(records);
}
