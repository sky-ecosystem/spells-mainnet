import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { getChainDetailsFromSheet } from "../src/sheet.js";

beforeEach(() => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
});

describe("getChainDetailsFromSheet", () => {
    test.each([
        {
            scenario: "missing recovery address",
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,eip155:8453,\n",
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
            csv: "Name,Chain Id,Asset Recovery Address\n,eip155:8453,0x1000000000000000000000000000000000000001\n",
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
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,,0x1000000000000000000000000000000000000001\n",
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
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,,\n",
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
            csv: "Name,Chain Id,Asset Recovery Address,Notes\n,,,draft\n",
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
            csv: "Name,Chain Id,Asset Recovery Address,Notes\n,,,\n   ,   ,   ,   \n\n",
            warnings: [],
        },
    ])("handles $scenario", async ({ csv, warnings }) => {
        vi.stubGlobal(
            "fetch",
            vi.fn().mockResolvedValue(
                new Response(csv, {
                    headers: { "content-type": "text/csv" },
                }),
            ),
        );

        await expect(
            getChainDetailsFromSheet("https://example.test/chains.csv"),
        ).resolves.toEqual({
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
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002",
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: { chainName: "ETHEREUM" },
            },
        ],
        [
            "chain ID",
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETH_DUPLICATE,eip155:1,0x1000000000000000000000000000000000000002",
            { code: "DUPLICATE_CHAIN_ID", context: { chainId: "eip155:1" } },
        ],
    ])(
        "preserves earlier mappings for a duplicate %s",
        async (_case, csv, warning) => {
            vi.stubGlobal(
                "fetch",
                vi.fn().mockResolvedValue({
                    ok: true,
                    headers: { get: vi.fn().mockReturnValue("text/csv") },
                    text: vi.fn().mockResolvedValue(csv),
                }),
            );

            const { chainDetails, validationWarnings } =
                await getChainDetailsFromSheet(
                    "https://example.test/chain-details.csv",
                );

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
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000002\nBASE,eip155:8453,0x1000000000000000000000000000000000000003\n",
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
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002\nOTHER,eip155:2,0x1000000000000000000000000000000000000002\nBASE,eip155:8453,0x1000000000000000000000000000000000000003\n",
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
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nOTHER,eip155:1,0x1000000000000000000000000000000000000002\nOTHER,eip155:2,0x1000000000000000000000000000000000000002\nBASE,eip155:8453,0x1000000000000000000000000000000000000003\n",
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
        async (_scenario, csv, warnings) => {
            vi.stubGlobal(
                "fetch",
                vi.fn().mockResolvedValue(
                    new Response(csv, {
                        headers: { "content-type": "text/csv" },
                    }),
                ),
            );

            await expect(
                getChainDetailsFromSheet("https://example.test/chains.csv"),
            ).resolves.toEqual({
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
