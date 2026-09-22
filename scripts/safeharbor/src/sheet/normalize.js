import { decodeBase58, encodeBase58, isAddress, isHexString, toBeHex } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { findDuplicateIndexes } from "../utils/findDuplicateIndexes.js";

const STATUS = Object.freeze({
    ACTIVE: "ACTIVE",
    DISABLED: "DISABLED",
});
const CONTRACT_HEADERS = ["Status", "Chain", "Address", "isFactory"];
const CHAIN_DETAILS_HEADERS = ["Name", "Chain Id", "Asset Recovery Address"];

export function normalizeContractsInScope({ headers, records }, sheetChainDetails) {
    assertHeaders(headers, CONTRACT_HEADERS);
    const activeRecords = records.filter((record) => record.Status === STATUS.ACTIVE);
    const accountsByChainName = Object.fromEntries(
        activeRecords.reduce((chains, record) => {
            const accounts = chains.get(record.Chain) ?? [];
            accounts.push({
                accountAddress: record.Address,
                childContractScope: record.isFactory === "TRUE" ? 2 : 0,
            });
            return chains.set(record.Chain, accounts);
        }, new Map()),
    );

    return {
        value: buildChainStates(accountsByChainName, sheetChainDetails),
        warnings: [
            ...validateStatuses(records),
            ...validateKnownChains(accountsByChainName, sheetChainDetails),
            ...validateFactoryFlags(activeRecords),
            ...validateAccountAddresses(accountsByChainName, sheetChainDetails),
            ...validateUniqueAccounts(accountsByChainName),
        ],
    };
}

export function normalizeChainDetails({ headers, records }) {
    assertHeaders(headers, CHAIN_DETAILS_HEADERS);
    const chains = records.filter((record) => getMissingChainFields(record).length === 0);
    const duplicates = analyzeDuplicateChains(chains);

    return {
        value: buildChainLookups(getUniqueChains(chains, duplicates)),
        warnings: [
            ...records.flatMap(validateChainMetadataRecord),
            ...validateDuplicateChains(chains, duplicates),
            ...validateSupportedNamespaces(chains),
        ],
    };
}

function validateStatuses(records) {
    return records
        .filter(
            (record) =>
                // Ignores fully blank lines
                Object.values(record).some((v) => !!v) &&
                // Otherwise rejects records with invalid status
                !Object.values(STATUS).includes(record.Status),
        )
        .map((record) => ({
            code: $.INVALID_SHEET_STATUS,
            context: {
                chainName: record.Chain,
                address: record.Address,
                status: record.Status,
            },
        }));
}

function buildChainStates(accountsByChainName, sheetChainDetails) {
    return Object.fromEntries(
        Object.entries(accountsByChainName)
            .filter(([chainName]) => sheetChainDetails.caip2ChainId[chainName])
            .map(([chainName, accounts]) => [
                sheetChainDetails.caip2ChainId[chainName],
                {
                    accounts,
                    assetRecoveryAddress: sheetChainDetails.assetRecoveryAddress[chainName],
                },
            ]),
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
    return chains.filter((_chain, index) => !duplicates.nameIndexes.has(index) && !duplicates.idIndexes.has(index));
}

function buildChainLookups(chains) {
    return {
        caip2ChainId: Object.fromEntries(chains.map((chain) => [chain.Name, chain["Chain Id"]])),
        assetRecoveryAddress: Object.fromEntries(chains.map((chain) => [chain.Name, chain["Asset Recovery Address"]])),
        name: Object.fromEntries(chains.map((chain) => [chain["Chain Id"], chain.Name])),
    };
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
                firstChainId: duplicates.chainIds[duplicates.chainNames.indexOf(chain.Name)],
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
                firstChainName: duplicates.chainNames[duplicates.chainIds.indexOf(chain["Chain Id"])],
                duplicateChainName: chain.Name,
            },
        },
    ];
}

function validateSupportedNamespaces(chains) {
    return chains
        .filter((chain) => !isSupportedNamespace(chain["Chain Id"]))
        .map((chain) => ({
            code: $.UNSUPPORTED_SHEET_CHAIN_NAMESPACE,
            context: { chainName: chain.Name, chainId: chain["Chain Id"] },
        }));
}

function isSupportedNamespace(chainId) {
    return chainId.startsWith("eip155:") || chainId.startsWith("solana:");
}

function validateFactoryFlags(records) {
    return records
        .filter((record) => !["", "TRUE", "FALSE"].includes(record.isFactory))
        .map((record) => ({
            code: $.INVALID_SHEET_FACTORY_FLAG,
            context: {
                chainName: record.Chain,
                address: record.Address,
                column: "isFactory",
                value: record.isFactory,
            },
        }));
}

function validateKnownChains(sheetState, sheetChainDetails) {
    return Object.keys(sheetState)
        .filter((chainName) => !sheetChainDetails.caip2ChainId[chainName])
        .map((chainName) => ({
            code: $.UNKNOWN_SHEET_CHAIN,
            context: { chainName },
        }));
}

function validateUniqueAccounts(sheetState) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) => validateChainAccounts(chainName, accounts));
}

function validateChainAccounts(chainName, accounts) {
    const addresses = accounts.map(({ accountAddress }) => accountAddress);
    return [...findDuplicateIndexes(addresses)].map((index) => ({
        code: $.DUPLICATE_SHEET_ACCOUNT,
        context: {
            chainName,
            address: addresses[index],
            firstScope: accounts[addresses.indexOf(addresses[index])].childContractScope,
            duplicateScope: accounts[index].childContractScope,
        },
    }));
}

function validateAccountAddresses(sheetState, sheetChainDetails) {
    return Object.entries(sheetState).flatMap(([chainName, accounts]) => {
        const chainId = sheetChainDetails.caip2ChainId[chainName];
        return accounts.flatMap(({ accountAddress }) => {
            if (!accountAddress) {
                return [
                    {
                        code: $.MISSING_SHEET_ACCOUNT_ADDRESS,
                        context: { chainName },
                    },
                ];
            }
            if (!chainId || !isSupportedNamespace(chainId) || isValidAccountAddress(accountAddress, chainId)) {
                return [];
            }
            return [
                {
                    code: $.INVALID_SHEET_ACCOUNT_ADDRESS,
                    context: { chainName, chainId, address: accountAddress },
                },
            ];
        });
    });
}

function isValidAccountAddress(address, chainId) {
    if (chainId.startsWith("eip155:")) {
        return isValidEvmAddress(address);
    }
    if (chainId.startsWith("solana:")) {
        return isValidSolanaAddress(address);
    }
    return false;
}

function isValidEvmAddress(address) {
    return isHexString(address, 20) && isAddress(address);
}

function isValidSolanaAddress(address) {
    try {
        // Re-encode as 32 bytes to reject wrong-length or noncanonical Base58 values.
        return encodeBase58(toBeHex(decodeBase58(address), 32)) === address;
    } catch {
        return false;
    }
}

function assertHeaders(headers, requiredHeaders) {
    const missingHeaders = requiredHeaders.filter((header) => !headers.includes(header));
    if (missingHeaders.length === 0) {
        return;
    }
    const diagnostic = {
        code: $.MISSING_SHEET_HEADERS,
        context: { missingHeaders },
    };
    throw Object.assign(new Error(diagnostic.code), { diagnostic });
}

function getMissingChainFields(record) {
    return CHAIN_DETAILS_HEADERS.filter((field) => !record[field]);
}
