import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function normalizeContractsInScope(
    { headers, records },
    sheetChainDetails,
) {
    assertContractHeaders(headers);
    const activeRecords = getActiveContracts(records);
    const accountsByChainName = groupAccountsByChain(activeRecords);

    return {
        value: accountsByChainName,
        warnings: [
            ...validateKnownChains(accountsByChainName, sheetChainDetails),
            ...validateFactoryFlags(activeRecords, headers),
            ...validateAccountAddresses(accountsByChainName),
            ...validateUniqueAccounts(accountsByChainName),
        ],
    };
}

export function normalizeChainDetails({ headers, records }) {
    assertHeaders(headers, CHAIN_DETAILS_HEADERS);
    const chains = getCompleteChains(records);
    const duplicates = analyzeDuplicateChains(chains);

    return {
        value: buildChainLookups(getUniqueChains(chains, duplicates)),
        warnings: [
            ...validateChainMetadata(records),
            ...validateDuplicateChains(chains, duplicates),
        ],
    };
}

function getActiveContracts(records) {
    return records.filter((record) => record.Status === "ACTIVE");
}

function groupAccountsByChain(records) {
    return Object.fromEntries(records.reduce(addAccountToChain, new Map()));
}

function addAccountToChain(chains, record) {
    const accounts = chains.get(record.Chain) ?? [];
    accounts.push(normalizeAccount(record));
    return chains.set(record.Chain, accounts);
}

function normalizeAccount(record) {
    return {
        accountAddress: record.Address,
        // Handle both possible column names for the factory flag.
        childContractScope:
            record.isFactory === "TRUE" || record.IsFactory === "TRUE" ? 2 : 0,
    };
}

function getCompleteChains(records) {
    return records.filter(
        (record) => getMissingChainFields(record).length === 0,
    );
}

function analyzeDuplicateChains(chains) {
    const chainNames = chains.map((chain) => chain.Name);
    const chainIds = chains.map((chain) => chain["Chain Id"]);
    return {
        chainNames,
        chainIds,
        nameIndexes: findDuplicateIndexes(chainNames),
        idIndexes: findDuplicateIndexes(chainIds),
    };
}

function getUniqueChains(chains, duplicates) {
    return chains.filter(
        (_chain, index) =>
            !duplicates.nameIndexes.has(index) &&
            !duplicates.idIndexes.has(index),
    );
}

function buildChainLookups(chains) {
    return {
        caip2ChainId: Object.fromEntries(
            chains.map((chain) => [chain.Name, chain["Chain Id"]]),
        ),
        assetRecoveryAddress: Object.fromEntries(
            chains.map((chain) => [
                chain.Name,
                chain["Asset Recovery Address"],
            ]),
        ),
        name: Object.fromEntries(
            chains.map((chain) => [chain["Chain Id"], chain.Name]),
        ),
    };
}

function validateChainMetadata(records) {
    return records.flatMap(validateChainMetadataRecord);
}

function validateChainMetadataRecord(record) {
    const missingFields = getMissingChainFields(record);
    if (!Object.values(record).some(Boolean) || missingFields.length === 0) {
        return [];
    }
    return [
        {
            code: $.INCOMPLETE_CHAIN_METADATA,
            context: {
                chainName: record.Name,
                chainId: record["Chain Id"],
                missingFields,
            },
        },
    ];
}

function validateDuplicateChains(chains, duplicates) {
    return chains.flatMap((chain, index) => [
        ...validateDuplicateChainName(chain, index, duplicates),
        ...validateDuplicateChainId(chain, index, duplicates),
    ]);
}

function validateDuplicateChainName(chain, index, duplicates) {
    if (!duplicates.nameIndexes.has(index)) {
        return [];
    }
    return [
        {
            code: $.DUPLICATE_CHAIN_NAME,
            context: {
                chainName: chain.Name,
                firstChainId:
                    duplicates.chainIds[
                        duplicates.chainNames.indexOf(chain.Name)
                    ],
                duplicateChainId: chain["Chain Id"],
            },
        },
    ];
}

function validateDuplicateChainId(chain, index, duplicates) {
    if (!duplicates.idIndexes.has(index)) {
        return [];
    }
    return [
        {
            code: $.DUPLICATE_CHAIN_ID,
            context: {
                chainId: chain["Chain Id"],
                firstChainName:
                    duplicates.chainNames[
                        duplicates.chainIds.indexOf(chain["Chain Id"])
                    ],
                duplicateChainName: chain.Name,
            },
        },
    ];
}

function validateFactoryFlags(records, headers) {
    const columns = headers.filter(
        (header) => header === "isFactory" || header === "IsFactory",
    );
    return records.flatMap((record) =>
        columns.flatMap((column) => validateFactoryFlag(record, column)),
    );
}

function validateFactoryFlag(record, column) {
    if (["", "TRUE", "FALSE"].includes(record[column])) {
        return [];
    }
    return [
        {
            code: $.INVALID_SHEET_FACTORY_FLAG,
            context: {
                chainName: record.Chain,
                address: record.Address,
                column,
                value: record[column],
            },
        },
    ];
}

function validateKnownChains(sheetState, sheetChainDetails) {
    return Object.keys(sheetState).flatMap((chainName) =>
        validateKnownChain(chainName, sheetChainDetails),
    );
}

function validateKnownChain(chainName, sheetChainDetails) {
    if (Object.hasOwn(sheetChainDetails.caip2ChainId, chainName)) {
        return [];
    }
    return [
        {
            code: $.UNKNOWN_SHEET_CHAIN,
            context: { chainName },
        },
    ];
}

function validateUniqueAccounts(sheetState) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) =>
        validateChainAccounts(chainName, accounts),
    );
}

function validateChainAccounts(chainName, accounts) {
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
}

function validateAccountAddresses(sheetState) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) =>
        accounts.flatMap((account) =>
            validateAccountAddress(account, chainName),
        ),
    );
}

function validateAccountAddress({ accountAddress }, chainName) {
    if (accountAddress) {
        return [];
    }
    return [
        {
            code: $.MISSING_SHEET_ACCOUNT_ADDRESS,
            context: { chainName },
        },
    ];
}

function assertContractHeaders(headers) {
    assertHeaders(headers, [
        "Status",
        "Chain",
        "Address",
        headers.includes("IsFactory") ? "IsFactory" : "isFactory",
    ]);
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
