import { parse } from "csv-parse/sync";

/**
 * @typedef {Object} CsvContractScopeRecord
 * @property {string} Status
 * @property {string} Chain
 * @property {string} Address
 * @property {string} [isFactory]
 * @property {string} [IsFactory]
 */

/**
 * @typedef {Object} SafeHarborAccount
 * @property {string} accountAddress
 * @property {number} childContractScope
 */

/**
 * @typedef {Object} CsvChainDetailsRecord
 * @property {string} [Name]
 * @property {string} [Chain Id]
 * @property {string} [Asset Recovery Address]
 */

/**
 * @typedef {Object} ChainDetails
 * @property {Record<string, string>} caip2ChainId
 * @property {Record<string, string>} assetRecoveryAddress
 * @property {Record<string, string>} name
 */

/**
 * Downloads CSV data from the provided URL, validates the response type, and
 * parses it into an array of records using header names as object keys.
 *
 * @param {string} url
 * @returns {Promise<Record<string, string>[]>}
 */
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

/**
 * Normalizes the contracts-in-scope sheet into a chain-keyed mapping of
 * accounts, filtering out non-active rows.
 *
 * Factory rows are mapped to `childContractScope = 2`; all other active rows
 * are treated as regular contracts with `childContractScope = 0`.
 *
 * @param {CsvContractScopeRecord[]} records
 * @returns {Record<string, SafeHarborAccount[]>}
 */
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

/**
 * Fetches and normalizes the contracts-in-scope CSV.
 *
 * @param {string} url
 * @returns {Promise<Record<string, SafeHarborAccount[]>>}
 */
export async function getNormalizedContractsInScopeFromCSV(url) {
    const records = await downloadAndParse(url);
    return normalizeContractsInScope(records);
}

/**
 * Fetches and normalizes the chain details CSV into lookup tables keyed by
 * chain name and CAIP-2 chain id.
 *
 * Rows missing any required field are ignored. Duplicate chain names or chain
 * ids are accepted but warned about, with later rows overwriting earlier ones.
 *
 * @param {string} url
 * @returns {Promise<ChainDetails>}
 */
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
