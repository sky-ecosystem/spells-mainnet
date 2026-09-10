import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function normalizeContractsInScope({ headers, records }, chainDetails) {
    assertHeaders(headers, [
        "Status",
        "Chain",
        "Address",
        headers.includes("IsFactory") ? "IsFactory" : "isFactory",
    ]);
    const value = Object.fromEntries(
        records
            .filter((record) => record.Status === "ACTIVE")
            .reduce((chains, record) => {
                const accounts = chains.get(record.Chain) ?? [];

                accounts.push({
                    accountAddress: record.Address,
                    // Handle both possible column names for the factory flag.
                    childContractScope:
                        record.isFactory === "TRUE" ||
                        record.IsFactory === "TRUE"
                            ? 2
                            : 0,
                });
                return chains.set(record.Chain, accounts);
            }, new Map()),
    );

    return {
        value,
        warnings: [
            ...validateKnownChains(value, chainDetails),
            ...validateAccountAddresses(value),
            ...validateUniqueAccounts(value),
        ],
    };
}

export function normalizeChainDetails({ headers, records }) {
    assertHeaders(headers, CHAIN_DETAILS_HEADERS);
    const chains = records.filter(
        (record) => getMissingChainFields(record).length === 0,
    );
    const chainNames = chains.map((chain) => chain.Name);
    const chainIds = chains.map((chain) => chain["Chain Id"]);
    const duplicateNameIndexes = findDuplicateIndexes(chainNames);
    const duplicateIdIndexes = findDuplicateIndexes(chainIds);
    const uniqueChains = chains.filter(
        (_chain, index) =>
            !duplicateNameIndexes.has(index) && !duplicateIdIndexes.has(index),
    );
    return {
        value: {
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
        warnings: [
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
                              context: {
                                  chainName: chain.Name,
                                  firstChainId:
                                      chainIds[chainNames.indexOf(chain.Name)],
                                  duplicateChainId: chain["Chain Id"],
                              },
                          },
                      ]
                    : []),
                ...(duplicateIdIndexes.has(index)
                    ? [
                          {
                              code: $.DUPLICATE_CHAIN_ID,
                              context: {
                                  chainId: chain["Chain Id"],
                                  firstChainName:
                                      chainNames[
                                          chainIds.indexOf(chain["Chain Id"])
                                      ],
                                  duplicateChainName: chain.Name,
                              },
                          },
                      ]
                    : []),
            ]),
        ],
    };
}

function validateKnownChains(sheetState, chainDetails) {
    return Object.keys(sheetState)
        .filter(
            (chainName) => !Object.hasOwn(chainDetails.caip2ChainId, chainName),
        )
        .map((chainName) => ({
            code: $.UNKNOWN_SHEET_CHAIN,
            context: { chainName },
        }));
}

function validateUniqueAccounts(sheetState) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) => {
        const addresses = accounts.map(({ accountAddress }) => accountAddress);
        return [...findDuplicateIndexes(addresses)].map((index) => ({
            code: $.DUPLICATE_SHEET_ACCOUNT,
            context: {
                chainName,
                address: addresses[index],
                firstScope:
                    accounts[addresses.indexOf(addresses[index])]
                        .childContractScope,
                duplicateScope: accounts[index].childContractScope,
            },
        }));
    });
}

function validateAccountAddresses(sheetState) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) =>
        accounts
            .filter(({ accountAddress }) => !accountAddress)
            .map(() => ({
                code: $.MISSING_SHEET_ACCOUNT_ADDRESS,
                context: { chainName },
            })),
    );
}

function assertHeaders(headers, requiredHeaders) {
    const missingHeaders = requiredHeaders.filter(
        (header) => !headers.includes(header),
    );
    if (missingHeaders.length === 0) {
        return;
    }
    const diagnostic = {
        code: $.MISSING_SHEET_HEADERS,
        context: { missingHeaders },
    };
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}

const CHAIN_DETAILS_HEADERS = ["Name", "Chain Id", "Asset Recovery Address"];

function getMissingChainFields(record) {
    return CHAIN_DETAILS_HEADERS.filter((field) => !record[field]);
}
