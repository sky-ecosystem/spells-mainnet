import { Interface } from "ethers";
import { afterEach, expect, test, vi } from "vitest";
import { createReconciler } from "../src/reconcile.js";

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
});

test.each([
    {
        scenario: "clean reconciliation with raw bigint scopes",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expected: {
            chainDetails: {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
            onChainState: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
            },
            changes: [],
            validationWarnings: [],
        },
    },
    {
        scenario: "blocked planning with normalized source data",
        chainCSV: "Name,Chain Id,Asset Recovery Address\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\n",
        details: { chains: [] },
        expected: {
            chainDetails: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            onChainState: {},
            sheetState: {
                BASE: [
                    {
                        accountAddress:
                            "0x3000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
            },
            changes: null,
            validationWarnings: [
                { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "BASE" } },
            ],
        },
    },
])(
    "returns $scenario without encoding or reporting",
    async ({ chainCSV, contractCSV, details, expected }) => {
        const encoding = vi.spyOn(Interface.prototype, "encodeFunctionData");
        const stdout = vi.spyOn(console, "log");
        const stderr = vi.spyOn(console, "error");
        const warnings = vi.spyOn(console, "warn");
        vi.stubGlobal(
            "fetch",
            vi
                .fn()
                .mockResolvedValueOnce(
                    new Response(chainCSV, {
                        headers: { "content-type": "text/csv" },
                    }),
                )
                .mockResolvedValueOnce(
                    new Response(contractCSV, {
                        headers: { "content-type": "text/csv" },
                    }),
                ),
        );
        const getAgreementDetails = vi.fn().mockResolvedValue(details);
        const reconcile = createReconciler({ getAgreementDetails });

        expect(await reconcile()).toEqual(expected);
        expect(getAgreementDetails).toHaveBeenCalledExactlyOnceWith();
        expect(encoding).not.toHaveBeenCalled();
        expect(stdout).not.toHaveBeenCalled();
        expect(stderr).not.toHaveBeenCalled();
        expect(warnings).not.toHaveBeenCalled();
    },
);
