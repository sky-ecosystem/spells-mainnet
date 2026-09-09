import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function normalizeContractsInScope({ headers, records }) {
    const [diagnostic] = validateHeaders(headers, [
        "Status",
        "Chain",
        "Address",
        headers.includes("IsFactory") ? "IsFactory" : "isFactory",
    ]);
    if (diagnostic) {
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
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

export function normalizeChainDetails({ headers, records }) {
    const [diagnostic] = validateHeaders(headers, CHAIN_DETAILS_HEADERS);
    if (diagnostic) {
        throw Object.assign(new Error(diagnostic.code), { diagnostic });
    }
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
                .map((record) => ({
                    code: $.INCOMPLETE_CHAIN_METADATA,
                    context: {
                        chainName: record.Name,
                        chainId: record["Chain Id"],
                        missingFields: getMissingChainFields(record),
                    },
                })),
            ...chains.flatMap((chain, index) => [
                ...(duplicateNameIndexes.has(index)
                    ? [
                          {
                              code: $.DUPLICATE_CHAIN_NAME,
                              context: { chainName: chain.Name },
                          },
                      ]
                    : []),
                ...(duplicateIdIndexes.has(index)
                    ? [
                          {
                              code: $.DUPLICATE_CHAIN_ID,
                              context: { chainId: chain["Chain Id"] },
                          },
                      ]
                    : []),
            ]),
        ],
    };
}

export function validateHeaders(headers, requiredHeaders) {
    const missingHeaders = requiredHeaders.filter(
        (header) => !headers.includes(header),
    );
    return missingHeaders.length > 0
        ? [
              {
                  code: $.MISSING_SHEET_HEADERS,
                  context: { missingHeaders },
              },
          ]
        : [];
}

const CHAIN_DETAILS_HEADERS = ["Name", "Chain Id", "Asset Recovery Address"];

function getMissingChainFields(record) {
    return CHAIN_DETAILS_HEADERS.filter((field) => !record[field]);
}
