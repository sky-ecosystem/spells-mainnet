import { describe, expect, test } from "vitest";
import {
    normalizeChainDetails,
    normalizeContractsInScope,
} from "./normalize.js";

test("rejects missing headers in required order", () => {
    expect(() =>
        normalizeContractsInScope({ headers: ["Status"], records: [] }),
    ).toThrow(
        expect.objectContaining({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: { missingHeaders: ["Chain", "Address", "isFactory"] },
            },
        }),
    );
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
    ).toEqual({ state: {}, warnings: [] });
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
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
                headers: [
                    "Name",
                    "Chain Id",
                    "Asset Recovery Address",
                    "Notes",
                ],
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
                        missingFields: [
                            "Name",
                            "Chain Id",
                            "Asset Recovery Address",
                        ],
                    },
                },
            ],
        },
        {
            scenario: "completely blank rows",
            sheet: {
                headers: [
                    "Name",
                    "Chain Id",
                    "Asset Recovery Address",
                    "Notes",
                ],
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
            chainDetails: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            validationWarnings: warnings,
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                ],
            },
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: { chainName: "ETHEREUM" },
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETH_DUPLICATE",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                ],
            },
            { code: "DUPLICATE_CHAIN_ID", context: { chainId: "eip155:1" } },
        ],
    ])(
        "preserves earlier mappings for a duplicate %s",
        (_case, sheet, warning) => {
            const { chainDetails, validationWarnings } =
                normalizeChainDetails(sheet);

            expect(validationWarnings).toEqual([warning]);
            expect(chainDetails).toEqual({
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            });
        },
    );

    test.each([
        [
            "both name and ID",
            {
                headers: ["Name", "Chain Id", "Asset Recovery Address"],
                records: [
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: { chainName: "ETHEREUM" },
                },
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: { chainId: "eip155:1" },
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "ETHEREUM",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: { chainName: "ETHEREUM" },
                },
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: { chainId: "eip155:2" },
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
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000001",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:1",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "OTHER",
                        "Chain Id": "eip155:2",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000002",
                    },
                    {
                        Name: "BASE",
                        "Chain Id": "eip155:8453",
                        "Asset Recovery Address":
                            "0x1000000000000000000000000000000000000003",
                    },
                ],
            },
            [
                {
                    code: "DUPLICATE_CHAIN_ID",
                    context: { chainId: "eip155:1" },
                },
                {
                    code: "DUPLICATE_CHAIN_NAME",
                    context: { chainName: "OTHER" },
                },
            ],
        ],
    ])(
        "diagnoses %s while retaining unrelated mappings",
        (_scenario, sheet, warnings) => {
            expect(normalizeChainDetails(sheet)).toEqual({
                chainDetails: {
                    caip2ChainId: { ETHEREUM: "eip155:1", BASE: "eip155:8453" },
                    assetRecoveryAddress: {
                        ETHEREUM: "0x1000000000000000000000000000000000000001",
                        BASE: "0x1000000000000000000000000000000000000003",
                    },
                    name: { "eip155:1": "ETHEREUM", "eip155:8453": "BASE" },
                },
                validationWarnings: warnings,
            });
        },
    );
});

test("groups active contracts in order with exact addresses and both factory aliases", () => {
    const result = normalizeContractsInScope(
        {
            headers: ["Status", "Chain", "Address", "isFactory", "IsFactory"],
            records: [
                {
                    Status: "INACTIVE",
                    Chain: "IGNORED",
                    Address: "InactiveAccount",
                    isFactory: "TRUE",
                    IsFactory: "TRUE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "AccountUpperCase",
                    isFactory: "FALSE",
                    IsFactory: "TRUE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "ETHEREUM",
                    Address: "0xA000000000000000000000000000000000000001",
                    isFactory: "TRUE",
                    IsFactory: "FALSE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "accountUpperCase",
                    isFactory: "FALSE",
                    IsFactory: "FALSE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "SOLANA",
                    Address: "AccountUpperCase",
                    isFactory: "FALSE",
                    IsFactory: "FALSE",
                },
                {
                    Status: "ACTIVE",
                    Chain: "ETHEREUM",
                    Address: "0xa000000000000000000000000000000000000001",
                    isFactory: "true",
                    IsFactory: "FALSE",
                },
                {
                    Status: "active",
                    Chain: "IGNORED",
                    Address: "LowercaseStatusAccount",
                    isFactory: "FALSE",
                    IsFactory: "FALSE",
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

    expect(Object.keys(result.state)).toEqual(["SOLANA", "ETHEREUM"]);
    expect(result.state).toEqual({
        SOLANA: [
            { accountAddress: "AccountUpperCase", childContractScope: 2 },
            { accountAddress: "accountUpperCase", childContractScope: 0 },
            { accountAddress: "AccountUpperCase", childContractScope: 0 },
        ],
        ETHEREUM: [
            {
                accountAddress: "0xA000000000000000000000000000000000000001",
                childContractScope: 2,
            },
            {
                accountAddress: "0xa000000000000000000000000000000000000001",
                childContractScope: 0,
            },
        ],
    });
    expect(result.warnings).toEqual([
        {
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: { chainName: "SOLANA", address: "AccountUpperCase" },
        },
    ]);
});

test("reports unknown chains and duplicate accounts without dropping records", () => {
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
                        Status: "INACTIVE",
                        Chain: "IGNORED",
                        Address: "0x2000000000000000000000000000000000000001",
                        isFactory: "FALSE",
                    },
                ],
            },
            { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
        ),
    ).toEqual({
        state: {
            ETHEREUM: [
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000001",
                    childContractScope: 0,
                },
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000002",
                    childContractScope: 0,
                },
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000002",
                    childContractScope: 0,
                },
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000001",
                    childContractScope: 2,
                },
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000002",
                    childContractScope: 2,
                },
            ],
            BASE: [
                {
                    accountAddress:
                        "0x2000000000000000000000000000000000000001",
                    childContractScope: 2,
                },
            ],
        },
        warnings: [
            { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "ETHEREUM" } },
            { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "BASE" } },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                },
            },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                },
            },
        ],
    });
});
