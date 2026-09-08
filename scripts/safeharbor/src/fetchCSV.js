import { parse } from "csv-parse/sync";
import { findDuplicateIndexes } from "./utils/findDuplicateIndexes.js";

const CHAIN_DETAILS_HEADERS = ["Name", "Chain Id", "Asset Recovery Address"];

async function downloadAndParse(url) {
    console.warn(`Fetching CSV from ${url}`);
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

function validateHeaders(headers, requiredHeaders) {
    const missingHeaders = requiredHeaders.filter(
        (header) => !headers.includes(header),
    );
    if (missingHeaders.length > 0) {
        throw new Error(
            `Missing required CSV headers: ${missingHeaders.join(", ")}`,
        );
    }
}

function normalizeContractsInScope(records) {
    return records
        .filter((record) => record.Status === "ACTIVE")
        .reduce((chains, record) => {
            const chain = record.Chain;
            if (!chains[chain]) {
                chains[chain] = [];
            }

            // Handle both possible column names for factory flag
            const isFactory =
                record.isFactory === "TRUE" || record.IsFactory === "TRUE";

            chains[chain].push({
                accountAddress: record.Address,
                childContractScope: isFactory ? 2 : 0,
            });
            return chains;
        }, {});
}

export async function getNormalizedContractsInScopeFromCSV(url) {
    const { headers, records } = await downloadAndParse(url);
    validateHeaders(headers, [
        "Status",
        "Chain",
        "Address",
        headers.includes("IsFactory") ? "IsFactory" : "isFactory",
    ]);
    return normalizeContractsInScope(records);
}

export async function getChainDetailsFromCSV(url) {
    const { headers, records } = await downloadAndParse(url);
    validateHeaders(headers, CHAIN_DETAILS_HEADERS);
    return normalizeChainDetails(records);
}

function normalizeChainDetails(records) {
    const chains = records.filter(
        (record) => getMissingChainFields(record).length === 0,
    );
    const duplicateNameIndexes = findDuplicateIndexes(
        chains.map((chain) => chain.Name),
    );
    const duplicateIdIndexes = findDuplicateIndexes(
        chains.map((chain) => chain["Chain Id"]),
    );
    const uniqueChains = chains.filter(
        (_chain, index) =>
            !duplicateNameIndexes.has(index) && !duplicateIdIndexes.has(index),
    );
    return {
        chainDetails: {
            caip2ChainId: Object.fromEntries(
                uniqueChains.map((chain) => [chain.Name, chain["Chain Id"]]),
            ),
            assetRecoveryAddress: Object.fromEntries(
                uniqueChains.map((chain) => [
                    chain.Name,
                    chain["Asset Recovery Address"],
                ]),
            ),
            name: Object.fromEntries(
                uniqueChains.map((chain) => [chain["Chain Id"], chain.Name]),
            ),
        },
        validationWarnings: [
            ...records
                .filter((record) => Object.values(record).some(Boolean))
                .filter((record) => getMissingChainFields(record).length > 0)
                .map(
                    (record) =>
                        `Incomplete chain details in CSV: name='${record.Name}', chainId='${record["Chain Id"]}'; missing ${getMissingChainFields(record).join(", ")}`,
                ),
            ...chains.flatMap((chain, index) => [
                ...(duplicateNameIndexes.has(index)
                    ? [`Duplicate chain name found in CSV: ${chain.Name}`]
                    : []),
                ...(duplicateIdIndexes.has(index)
                    ? [`Duplicate chain ID found in CSV: ${chain["Chain Id"]}`]
                    : []),
            ]),
        ],
    };
}

function getMissingChainFields(record) {
    return CHAIN_DETAILS_HEADERS.filter((field) => !record[field]);
}
