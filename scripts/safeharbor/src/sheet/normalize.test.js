import { describe, expect, test } from "vitest";
import {
    normalizeChainDetails,
    normalizeContractsInScope,
    validateHeaders,
} from "./normalize.js";

test("returns every missing header in required order", () => {
    expect(validateHeaders(["Status"], ["Status", "Chain", "Address"])).toEqual(
        [
            {
                code: "MISSING_SHEET_HEADERS",
                context: { missingHeaders: ["Chain", "Address"] },
            },
        ],
    );
});

test("accepts required headers with extra columns", () => {
    expect(
        validateHeaders(["Notes", "Chain", "Status"], ["Status", "Chain"]),
    ).toEqual([]);
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
    const result = normalizeContractsInScope({
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
    });

    expect(Object.keys(result)).toEqual(["SOLANA", "ETHEREUM"]);
    expect(result).toEqual({
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
});
