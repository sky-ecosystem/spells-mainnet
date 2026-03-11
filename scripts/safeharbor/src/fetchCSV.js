import { parse } from "csv-parse/sync";

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
    const records = await downloadAndParse(url);
    return normalizeContractsInScope(records);
}

export async function getChainDetailsFromCSV(url) {
    const records = await downloadAndParse(url);

    // Normalize chain details data
    const caip2ChainId = {};
    const assetRecoveryAddress = {};
    const name = {};

    records.forEach((record) => {
        const chainName = record["Name"];
        const chainId = record["Chain Id"];
        const chainAssetRecoveryAddress = record["Asset Recovery Address"];

        if (chainName && chainId && chainAssetRecoveryAddress) {
            // Check for duplicate names - if key already exists in object
            if (caip2ChainId[chainName]) {
                console.warn(
                    `⚠️  Warning: Duplicate chain name found in CSV: ${chainName} ⚠️`,
                );
            }

            // Check for duplicate chain IDs - if key already exists in object
            if (name[chainId]) {
                console.warn(
                    `⚠️  Warning: Duplicate chain ID found in CSV: ${chainId} ⚠️`,
                );
            }

            caip2ChainId[chainName] = chainId;
            assetRecoveryAddress[chainName] = chainAssetRecoveryAddress;
            name[chainId] = chainName;
        }
    });

    return {
        caip2ChainId,
        assetRecoveryAddress,
        name,
    };
}
