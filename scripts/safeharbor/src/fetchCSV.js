import { parse } from "csv-parse/sync";

/**
 * Fetches a CSV from the given URL, validates the response is CSV, and parses it into records.
 *
 * Performs an HTTP GET to the provided URL, expects a response whose Content-Type includes
 * "text/csv", and parses the CSV with headers as keys (columns: true), skipping empty lines
 * and trimming fields.
 *
 * @param {string} url - URL that returns CSV data (must be reachable and return Content-Type including "text/csv").
 * @returns {Array<Object>} Parsed CSV records (each row represented as an object keyed by column headers).
 * @throws {Error} If the fetch fails, the response status is not OK, or the Content-Type is not CSV.
 */
async function downloadAndAParse(url) {
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
 * Group and transform CSV-derived records into per-chain account lists.
 *
 * Filters input records to those with Status === "ACTIVE", groups them by the
 * Chain field, and maps each record to an object with `accountAddress` (from
 * the Address field) and `childContractScope` (2 when the record's `isFactory`
 * or `IsFactory` field equals the string "TRUE", otherwise 0).
 *
 * @param {Array<Object>} records - Array of parsed CSV record objects. Expected fields: `Status`, `Chain`, `Address`, and either `isFactory` or `IsFactory`.
 * @returns {Object<string, Array<{accountAddress: string, childContractScope: number}>>} An object keyed by chain name where each value is an array of transformed records for that chain.
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
 * Fetches CSV data from the given URL, parses it, and returns a normalized grouping by chain.
 *
 * The URL should point to a publicly accessible CSV (response Content-Type must include "text/csv").
 * The returned object maps chain names to arrays of records with the shape:
 * { accountAddress: string, childContractScope: number } where childContractScope is 2 for factory entries and 0 otherwise.
 *
 * @param {string} url - URL of the CSV to fetch and normalize.
 * @return {Promise<Object<string, Array<{accountAddress: string, childContractScope: number}>>>} Normalized data grouped by chain.
 */
export async function getNormalizedDataFromCSV(url) {
    const records = await downloadAndAParse(url);
    return normalize(records);
}
