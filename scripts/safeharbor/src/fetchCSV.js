import { parse } from "csv-parse/sync";

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

export async function getNormalizedDataFromCSV(url) {
    const records = await downloadAndAParse(url);
    return normalize(records);
}
