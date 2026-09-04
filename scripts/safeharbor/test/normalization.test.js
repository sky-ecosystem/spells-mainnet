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
            expect.stringContaining("caip2ChainId='eip155:999999'"),
        ]);
    });
});

describe("getChainDetailsFromCSV", () => {
    test.each([
        [
            "chain name",
            "ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002",
            "⚠️  Warning: Duplicate chain name found in CSV: ETHEREUM ⚠️",
        ],
        [
            "chain ID",
            "ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETH_DUPLICATE,eip155:1,0x1000000000000000000000000000000000000002",
            "⚠️  Warning: Duplicate chain ID found in CSV: eip155:1 ⚠️",
        ],
    ])("returns warnings for a duplicate %s", async (_case, rows, warning) => {
        vi.stubGlobal(
            "fetch",
            vi.fn().mockResolvedValue({
                ok: true,
                headers: { get: vi.fn().mockReturnValue("text/csv") },
                text: vi
                    .fn()
                    .mockResolvedValue(
                        `Name,Chain Id,Asset Recovery Address\n${rows}`,
                    ),
            }),
        );

        const { validationWarnings } = await getChainDetailsFromCSV(
            "https://example.test/chain-details.csv",
        );

        expect(validationWarnings).toEqual([warning]);
    });
});
