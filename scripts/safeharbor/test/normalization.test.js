import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { getChainDetailsFromCSV } from "../src/fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "../src/fetchOnchain.js";

beforeEach(() => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
});

describe("getNormalizedDataFromOnchainState", () => {
    test("returns warnings for unknown on-chain chains", async () => {
        const agreementContract = {
            getDetails: vi.fn().mockResolvedValue({
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            ["0x2000000000000000000000000000000000000001", 0],
                        ],
                    },
                    {
                        caip2ChainId: "eip155:999999",
                        assetRecoveryAddress:
                            "0x10000000000000000000000000000000000000fe",
                        accounts: [
                            ["0x6000000000000000000000000000000000000001", 0],
                        ],
                    },
                ],
            }),
        };

        const { onChainState, validationWarnings } =
            await getNormalizedDataFromOnchainState(agreementContract, {
                name: { "eip155:1": "ETHEREUM" },
            });

        expect(onChainState).toEqual({
            ETHEREUM: {
                accounts: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        });
        expect(validationWarnings).toEqual([
            "Unknown chain details in on-chain state: caip2ChainId='eip155:999999'.\nTo either remove or keep this chain, please add the chain details to the chain details tab in the Google Sheet.",
        ]);
    });
});

describe("getChainDetailsFromCSV", () => {
    test.each([
        {
            scenario: "missing recovery address",
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,eip155:8453,\n",
            warnings: [
                "Incomplete chain details in CSV: name='BASE', chainId='eip155:8453'; missing Asset Recovery Address",
            ],
        },
        {
            scenario: "missing chain name",
            csv: "Name,Chain Id,Asset Recovery Address\n,eip155:8453,0x1000000000000000000000000000000000000001\n",
            warnings: [
                "Incomplete chain details in CSV: name='', chainId='eip155:8453'; missing Name",
            ],
        },
        {
            scenario: "missing chain ID",
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,,0x1000000000000000000000000000000000000001\n",
            warnings: [
                "Incomplete chain details in CSV: name='BASE', chainId=''; missing Chain Id",
            ],
        },
        {
            scenario: "multiple missing fields",
            csv: "Name,Chain Id,Asset Recovery Address\nBASE,,\n",
            warnings: [
                "Incomplete chain details in CSV: name='BASE', chainId=''; missing Chain Id, Asset Recovery Address",
            ],
        },
        {
            scenario: "only an extra column is populated",
            csv: "Name,Chain Id,Asset Recovery Address,Notes\n,,,draft\n",
            warnings: [
                "Incomplete chain details in CSV: name='', chainId=''; missing Name, Chain Id, Asset Recovery Address",
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
            getChainDetailsFromCSV("https://example.test/chains.csv"),
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
            "Duplicate chain name found in CSV: ETHEREUM",
        ],
        [
            "chain ID",
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETH_DUPLICATE,eip155:1,0x1000000000000000000000000000000000000002",
            "Duplicate chain ID found in CSV: eip155:1",
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
                await getChainDetailsFromCSV(
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
                "Duplicate chain name found in CSV: ETHEREUM",
                "Duplicate chain ID found in CSV: eip155:1",
            ],
        ],
        [
            "an ID previously seen in a rejected row",
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002\nOTHER,eip155:2,0x1000000000000000000000000000000000000002\nBASE,eip155:8453,0x1000000000000000000000000000000000000003\n",
            [
                "Duplicate chain name found in CSV: ETHEREUM",
                "Duplicate chain ID found in CSV: eip155:2",
            ],
        ],
        [
            "a name previously seen in a rejected row",
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nOTHER,eip155:1,0x1000000000000000000000000000000000000002\nOTHER,eip155:2,0x1000000000000000000000000000000000000002\nBASE,eip155:8453,0x1000000000000000000000000000000000000003\n",
            [
                "Duplicate chain ID found in CSV: eip155:1",
                "Duplicate chain name found in CSV: OTHER",
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
                getChainDetailsFromCSV("https://example.test/chains.csv"),
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
