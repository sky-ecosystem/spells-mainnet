import { describe, expect, test } from "vitest";
import { normalizeChainDetails, normalizeContractsInScope } from "./normalize.js";

test("rejects missing headers in required order", () => {
    expect(() => normalizeContractsInScope({ headers: ["Status"], records: [] })).toThrow(
        expect.objectContaining({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: { missingHeaders: ["Chain", "Address", "isFactory"] },
            },
        }),
    );
});

test("warns for unrecognized statuses on populated rows without treating them as active", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory"],
                records: [
                    {
                        Status: "DISABLED",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "PAUSED",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000002",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000003",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "active",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000004",
                        isFactory: "FALSE",
                    },
                    { Status: "", Chain: "", Address: "", isFactory: "" },
                ],
            },
            {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: { ETHEREUM: "0x1000000000000000000000000000000000000001" },
                name: { "eip155:1": "ETHEREUM" },
            },
        ),
    ).toStrictEqual({
        value: {},
        warnings: [
            {
                code: "INVALID_SHEET_STATUS",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    status: "PAUSED",
                },
            },
            {
                code: "INVALID_SHEET_STATUS",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000003",
                    status: "",
                },
            },
            {
                code: "INVALID_SHEET_STATUS",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000004",
                    status: "active",
                },
            },
        ],
    });
});

test("uses only isFactory when an IsFactory column is also present", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory", "IsFactory"],
                records: [
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "FALSE",
                        IsFactory: "TRUE",
                    },
                ],
            },
            {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: { ETHEREUM: "0x1000000000000000000000000000000000000001" },
                name: { "eip155:1": "ETHEREUM" },
            },
        ),
    ).toStrictEqual({
        value: {
            "eip155:1": {
                accounts: [{ accountAddress: "0x2000000000000000000000000000000000000001", childContractScope: 0 }],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [],
    });
});

test("diagnoses invalid active addresses without dropping records or normalizing their values", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory"],
                records: [
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "DISABLED",
                        Chain: "ETHEREUM",
                        Address: "",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: " ",
                        isFactory: "FALSE",
                    },
                ],
            },
            {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
        ),
    ).toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    { accountAddress: "", childContractScope: 0 },
                    { accountAddress: " ", childContractScope: 0 },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [
            {
                code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
            {
                code: "INVALID_SHEET_ACCOUNT_ADDRESS",
                context: {
                    chainName: "ETHEREUM",
                    chainId: "eip155:1",
                    address: " ",
                },
            },
        ],
    });
});

test.each([
    {
        scenario: "an EVM address with an invalid checksum",
        chainName: "ETHEREUM",
        chainId: "eip155:1",
        address: "0x52908400098527886E0F7030069857D2E4169Ee7",
        assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
    },
    {
        scenario: "an ICAP address on an EVM chain",
        chainName: "ETHEREUM",
        chainId: "eip155:1",
        address: "XE65GB6LDNXYOFTX0NSV3FUWKOWIXAMJK36",
        assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
    },
    {
        scenario: "a Solana address with fewer than 32 bytes",
        chainName: "SOLANA",
        chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
        address: "1",
        assetRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
    },
    {
        scenario: "a Solana address with an invalid Base58 character",
        chainName: "SOLANA",
        chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
        address: "0",
        assetRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
    },
])("diagnoses $scenario", ({ chainName, chainId, address, assetRecoveryAddress }) => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory"],
                records: [{ Status: "ACTIVE", Chain: chainName, Address: address, isFactory: "FALSE" }],
            },
            {
                caip2ChainId: { [chainName]: chainId },
                assetRecoveryAddress: { [chainName]: assetRecoveryAddress },
                name: { [chainId]: chainName },
            },
        ),
    ).toEqual({
        value: {
            [chainId]: {
                accounts: [{ accountAddress: address, childContractScope: 0 }],
                assetRecoveryAddress,
            },
        },
        warnings: [
            {
                code: "INVALID_SHEET_ACCOUNT_ADDRESS",
                context: { chainName, chainId, address },
            },
        ],
    });
});

test("checks factory flags while accepting blanks and ignoring disabled rows", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory"],
                records: [
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "TRU",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000002",
                        isFactory: "false",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000003",
                        isFactory: "",
                    },
                    {
                        Status: "DISABLED",
                        Chain: "ETHEREUM",
                        Address: "D",
                        isFactory: "TRU",
                    },
                ],
            },
            {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
        ),
    ).toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    { accountAddress: "0x2000000000000000000000000000000000000001", childContractScope: 0 },
                    { accountAddress: "0x2000000000000000000000000000000000000002", childContractScope: 0 },
                    { accountAddress: "0x2000000000000000000000000000000000000003", childContractScope: 0 },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [
            {
                code: "INVALID_SHEET_FACTORY_FLAG",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    column: "isFactory",
                    value: "TRU",
                },
            },
            {
                code: "INVALID_SHEET_FACTORY_FLAG",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    column: "isFactory",
                    value: "false",
                },
            },
        ],
    });
});

test("accepts required headers with extra columns", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Notes", "Chain", "Status", "Address", "isFactory"],
                records: [],
            },
            { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
        ),
    ).toEqual({ value: {}, warnings: [] });
});

test("joins raw recovery addresses without mutating either source", () => {
    const sheet = {
        headers: ["Status", "Chain", "Address", "isFactory"],
        records: [
            {
                Status: "ACTIVE",
                Chain: "ETHEREUM",
                Address: "0x2000000000000000000000000000000000000001",
                isFactory: "TRUE",
            },
        ],
    };
    const metadata = {
        caip2ChainId: { ETHEREUM: "eip155:1", BASE: "eip155:8453" },
        assetRecoveryAddress: {
            ETHEREUM: " InvalidChecksumAndSpaces ",
            BASE: "OtherRecovery",
        },
        name: { "eip155:1": "ETHEREUM", "eip155:8453": "BASE" },
    };
    const originalSheet = structuredClone(sheet);
    const originalMetadata = structuredClone(metadata);

    expect(normalizeContractsInScope(sheet, metadata)).toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                ],
                assetRecoveryAddress: " InvalidChecksumAndSpaces ",
            },
        },
        warnings: [],
    });
    expect(sheet).toEqual(originalSheet);
    expect(metadata).toEqual(originalMetadata);
});

describe("normalizeChainDetails", () => {
    test.each([
        {
            scenario: "missing recovery address",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address": "",
                    },
                ],
            },
            warnings: [
                {
                    code: "INCOMPLETE_CHAIN_METADATA",
                    context: {
                        chainName: "BASE",
                        chainId: "eip155:8453",
                        missingFields: ["Asset Recovery Address"],
                    },
                },
            ],
        },
        {
            scenario: "missing chain name",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                ],
            },
            warnings: [
                {
                    code: "INCOMPLETE_CHAIN_METADATA",
                    context: {
                        chainName: "",
                        chainId: "eip155:8453",
                        missingFields: ["Name"],
                    },
                },
            ],
        },
        {
            scenario: "missing chain ID",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "BASE",
                        "Chain Id": "",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                ],
            },
            warnings: [
                {
                    code: "INCOMPLETE_CHAIN_METADATA",
                    context: {
                        chainName: "BASE",
                        chainId: "",
                        missingFields: ["Chain Id"],
                    },
                },
            ],
        },
        {
            scenario: "multiple missing fields",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "BASE",
                        "Chain Id": "",
                        "Asset Recovery Address": "",
                    },
                ],
            },
            warnings: [
                {
                    code: "INCOMPLETE_CHAIN_METADATA",
                    context: {
                        chainName: "BASE",
                        chainId: "",
                        missingFields: ["Chain Id", "Asset Recovery Address"],
                    },
                },
            ],
        },
        {
            scenario: "only an extra column is populated",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address", "Notes"],
                records: [
                    {
                        Name: "",
                        "Chain Id": "",
                        "Asset Recovery Address": "",
                        Notes: "draft",
                    },
                ],
            },
            warnings: [
                {
                    code: "INCOMPLETE_CHAIN_METADATA",
                    context: {
                        chainName: "",
                        chainId: "",
                        missingFields: ["Name", "Chain Id", "Asset Recovery Address"],
                    },
                },
            ],
        },
        {
            scenario: "completely blank rows",
            sheet: {
                headers: ["Name", "Chain Id", "Asset Recovery Address", "Notes"],
                records: [
                    {
                        Name: "",
                        "Chain Id": "",
                        "Asset Recovery Address": "",
                        Notes: "",
                    },
                    {
                        Name: "",
                        "Chain Id": "",
                        "Asset Recovery Address": "",
                        Notes: "",
                    },
                ],
            },
            warnings: [],
        },
    ])("handles $scenario", ({ sheet, warnings }) => {
        expect(normalizeChainDetails(sheet)).toEqual({
            value: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            warnings,
        });
    });

    test.each([
        [
            "chain name",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                ],
            },
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            },
        ],
        [
            "chain ID",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETH_DUPLICATE",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                ],
            },
            {
                code: "DUPLICATE_CHAIN_ID",
                context: {
                    chainId: "eip155:1",
                    firstChainName: "ETHEREUM",
                    duplicateChainName: "ETH_DUPLICATE",
                },
            },
        ],
    ])("preserves earlier mappings for a duplicate %s", (_case, sheet, warning) => {
        const { value, warnings } = normalizeChainDetails(sheet);

        expect(warnings).toEqual([warning]);
        expect(value).toEqual({
            caip2ChainId: { ETHEREUM: "eip155:1" },
            assetRecoveryAddress: {
                ETHEREUM: "0x1000000000000000000000000000000000000001",
            },
            name: { "eip155:1": "ETHEREUM" },
        });
    });

    test.each([
        [
            "both name and ID",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: {
                        chainName: "ETHEREUM",
                        firstChainId: "eip155:1",
                        duplicateChainId: "eip155:1",
                    },
                },
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: {
                        chainId: "eip155:1",
                        firstChainName: "ETHEREUM",
                        duplicateChainName: "ETHEREUM",
                    },
                },
            ],
        ],
        [
            "an ID previously seen in a rejected row",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: {
                        chainName: "ETHEREUM",
                        firstChainId: "eip155:1",
                        duplicateChainId: "eip155:2",
                    },
                },
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: {
                        chainId: "eip155:2",
                        firstChainName: "ETHEREUM",
                        duplicateChainName: "OTHER",
                    },
                },
            ],
        ],
        [
            "a name previously seen in a rejected row",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address": "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: {
                        chainId: "eip155:1",
                        firstChainName: "ETHEREUM",
                        duplicateChainName: "OTHER",
                    },
                },
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: {
                        chainName: "OTHER",
                        firstChainId: "eip155:1",
                        duplicateChainId: "eip155:2",
                    },
                },
            ],
        ],
    ])("diagnoses %s while retaining unrelated mappings", (_scenario, sheet, warnings) => {
        expect(normalizeChainDetails(sheet)).toEqual({
            value: {
                caip2ChainId: { ETHEREUM: "eip155:1", BASE: "eip155:8453" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                    BASE: "0x1000000000000000000000000000000000000003",
                },
                name: { "eip155:1": "ETHEREUM", "eip155:8453": "BASE" },
            },
            warnings,
        });
    });
});

test("groups active contracts in order with exact addresses and factory scopes", () => {
    const result = normalizeContractsInScope(
        {
            headers: ["Status", "Chain", "Address", "isFactory"],
            records: [
                {
                    Status: "DISABLED",
                    Chain: "IGNORED",
                    Address: "InactiveAccount",
                    isFactory: "TRUE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "So11111111111111111111111111111111111111112",
                    isFactory: "TRUE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "ETHEREUM",
                    Address: "0xA000000000000000000000000000000000000001",
                    isFactory: "TRUE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "so11111111111111111111111111111111111111112",
                    isFactory: "FALSE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "So11111111111111111111111111111111111111112",
                    isFactory: "FALSE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "ETHEREUM",
                    Address: "0xa000000000000000000000000000000000000001",
                    isFactory: "true",
                },
                {
                    Status: "DISABLED",
                    Chain: "IGNORED",
                    Address: "LowercaseStatusAccount",
                    isFactory: "FALSE",
                },
            ],
        },
        {
            caip2ChainId: {
                SOLANA: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                ETHEREUM: "eip155:1",
            },
            assetRecoveryAddress: {
                SOLANA: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                ETHEREUM: "0x1000000000000000000000000000000000000001",
            },
            name: {
                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "SOLANA",
                "eip155:1": "ETHEREUM",
            },
        },
    );

    expect(Object.keys(result.value)).toEqual(["solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", "eip155:1"]);
    expect(result.value).toEqual({
        "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": {
            accounts: [
                { accountAddress: "So11111111111111111111111111111111111111112", childContractScope: 2 },
                { accountAddress: "so11111111111111111111111111111111111111112", childContractScope: 0 },
                { accountAddress: "So11111111111111111111111111111111111111112", childContractScope: 0 },
            ],
            assetRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
        },
        "eip155:1": {
            accounts: [
                {
                    accountAddress: "0xA000000000000000000000000000000000000001",
                    childContractScope: 2,
                },
                {
                    accountAddress: "0xa000000000000000000000000000000000000001",
                    childContractScope: 0,
                },
            ],
            assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
        },
    });
    expect(result.warnings).toEqual([
        {
            code: "INVALID_SHEET_FACTORY_FLAG",
            context: {
                chainName: "ETHEREUM",
                address: "0xa000000000000000000000000000000000000001",
                column: "isFactory",
                value: "true",
            },
        },
        {
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: {
                chainName: "SOLANA",
                address: "So11111111111111111111111111111111111111112",
                firstScope: 2,
                duplicateScope: 0,
            },
        },
    ]);
});

test("omits unresolved chains while preserving their account diagnostics", () => {
    expect(
        normalizeContractsInScope(
            {
                headers: ["Status", "Chain", "Address", "isFactory"],
                records: [
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000002",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000002",
                        isFactory: "FALSE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "TRUE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "ETHEREUM",
                        Address: "0x2000000000000000000000000000000000000002",
                        isFactory: "TRUE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "BASE",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "TRUE",
                    },
                    {
                        Status: "ACTIVE",
                        Chain: "BASE",
                        Address: "",
                        isFactory: "invalid",
                    },
                    {
                        Status: "DISABLED",
                        Chain: "IGNORED",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "FALSE",
                    },
                ],
            },
            { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
        ),
    ).toEqual({
        value: {},
        warnings: [
            { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "ETHEREUM" } },
            { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "BASE" } },
            {
                code: "INVALID_SHEET_FACTORY_FLAG",
                context: {
                    chainName: "BASE",
                    address: "",
                    column: "isFactory",
                    value: "invalid",
                },
            },
            {
                code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                context: { chainName: "BASE" },
            },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0,
                    duplicateScope: 0,
                },
            },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 2,
                },
            },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0,
                    duplicateScope: 2,
                },
            },
        ],
    });
});
