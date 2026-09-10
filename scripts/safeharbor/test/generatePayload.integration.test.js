import { test, expect, describe, vi, beforeEach, afterEach } from "vitest";
import assert from "node:assert";
import { Contract, Interface, JsonRpcProvider } from "ethers";
import { dedent } from "./helpers/dedent.js";
import { generatePayload } from "../src/generation/index.js";
import { reconcile } from "../src/reconciliation/index.js";
import { createAgreementReader } from "../src/agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";
import AGREEMENT_V3_ABI from "../src/agreement/abis/agreement.json" with { type: "json" };

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

const getDetails = vi.fn();

let provider;
let consoleWarnSpy;
let consoleErrorSpy;
let consoleLogSpy;
let encodeSpy;

beforeEach(() => {
    provider = new JsonRpcProvider("https://rpc.example");
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi
            .fn()
            .mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });
    vi.stubGlobal("fetch", vi.fn());
    consoleWarnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    consoleErrorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    consoleLogSpy = vi.spyOn(console, "log").mockImplementation(() => {});
    encodeSpy = vi.spyOn(Interface.prototype, "encodeFunctionData");
});

afterEach(() => {
    try {
        expect(consoleWarnSpy).not.toHaveBeenCalled();
        expect(consoleErrorSpy).not.toHaveBeenCalled();
        expect(consoleLogSpy).not.toHaveBeenCalled();
    } finally {
        provider.destroy();
        vi.restoreAllMocks();
        vi.unstubAllGlobals();
        vi.resetAllMocks();
    }
});

async function generateFrom(fixture) {
    const report = await reconcileFrom(fixture);
    expect(report.validationWarnings).toEqual([]);
    const result = generatePayload(report.changes);
    payloadSnapshot(result.updates);
    return result;
}

async function reconcileFrom({ chainCSV, contractCSV, details }) {
    fetch
        .mockResolvedValueOnce(
            new Response(chainCSV, { headers: { "content-type": "text/csv" } }),
        )
        .mockResolvedValueOnce(
            new Response(contractCSV, {
                headers: { "content-type": "text/csv" },
            }),
        );
    getDetails.mockResolvedValue(details);
    const report = await reconcile({
        getAgreementState: createAgreementReader(provider),
        getSheetState,
        getSheetChainDetails,
    });
    expect(encodeSpy).not.toHaveBeenCalled();
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    return report;
}

describe("generatePayload", () => {
    test.each([
        {
            scenario: "an addition on an existing chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,A,FALSE
                ACTIVE,ETHEREUM,,FALSE
            `,
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [["A", 0n]],
                    },
                ],
            },
        },
        {
            scenario: "a full replacement on an existing chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,,TRUE
            `,
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [["A", 0n]],
                    },
                ],
            },
        },
        {
            scenario: "a new chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,,FALSE
            `,
            details: { chains: [] },
        },
    ])(
        "blocks an empty address for $scenario before encoding",
        async ({ contractCSV, details }) => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                `,
                contractCSV,
                details,
            });
            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                {
                    code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                    context: { chainName: "ETHEREUM" },
                },
            ]);
        },
    );

    describe("No changes scenario", () => {
        test("should generate no updates when onChain and CSV data match", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            // Assert - should have empty result since no changes needed
            assert.strictEqual(result.updates.length, 0);
            assert.strictEqual(result.solidityCode, "");
        });
    });

    describe("Account addition scenarios", () => {
        test("should generate addAccounts updates when new accounts are added to existing chains", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000002,TRUE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:1",
                        [
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000003",
                                childContractScope: 0,
                            },
                        ],
                    ],
                },
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:8453",
                        [
                            {
                                accountAddress:
                                    "0x3000000000000000000000000000000000000002",
                                childContractScope: 2,
                            },
                        ],
                    ],
                },
            ]);
        });
    });
    describe("Account removal scenarios", () => {
        test("should generate removeAccounts updates when accounts are removed", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "removeAccounts",
                    args: [
                        "eip155:1",
                        ["0x2000000000000000000000000000000000000002"],
                    ],
                },
                {
                    fn: "removeAccounts",
                    args: [
                        "eip155:42161",
                        ["0x4000000000000000000000000000000000000001"],
                    ],
                },
            ]);
        });
    });
    describe("Chain addition scenarios", () => {
        test("should generate addChains updates when new chains are introduced", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000001,FALSE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000002,TRUE
                    ACTIVE,SOLANA,3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "addChains",
                    args: [
                        [
                            {
                                caip2ChainId: "eip155:10",
                                assetRecoveryAddress:
                                    "0x1000000000000000000000000000000000000004",
                                accounts: [
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000001",
                                        childContractScope: 0,
                                    },
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000002",
                                        childContractScope: 2,
                                    },
                                ],
                            },
                            {
                                caip2ChainId:
                                    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                                assetRecoveryAddress:
                                    "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                                accounts: [
                                    {
                                        accountAddress:
                                            "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
                                        childContractScope: 0,
                                    },
                                ],
                            },
                        ],
                    ],
                },
            ]);
        });
    });
    describe("Chain removal scenarios", () => {
        test("should generate removeChains updates when chains are removed", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "removeChains",
                    args: [["eip155:8453", "eip155:42161"]],
                },
            ]);
        });
    });
    describe("Complex mixed scenarios", () => {
        test("should handle simultaneous chain additions, removals, and account changes", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000003,TRUE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                { fn: "removeChains", args: [["eip155:8453"]] },
                {
                    fn: "addChains",
                    args: [
                        [
                            {
                                caip2ChainId: "eip155:10",
                                assetRecoveryAddress:
                                    "0x1000000000000000000000000000000000000004",
                                accounts: [
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000001",
                                        childContractScope: 0,
                                    },
                                ],
                            },
                        ],
                    ],
                },
                {
                    fn: "removeAccounts",
                    args: [
                        "eip155:1",
                        ["0x2000000000000000000000000000000000000002"],
                    ],
                },
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:1",
                        [
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000003",
                                childContractScope: 0,
                            },
                        ],
                    ],
                },
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:42161",
                        [
                            {
                                accountAddress:
                                    "0x4000000000000000000000000000000000000003",
                                childContractScope: 2,
                            },
                        ],
                    ],
                },
            ]);
        });
        test("should preserve childContractScope values correctly in complex scenarios", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000005,FALSE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000003,TRUE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000004,FALSE
                    ACTIVE,OPTIMISM,0x5000000000000000000000000000000000000005,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "removeChains",
                    args: [["eip155:8453", "eip155:42161"]],
                },
                {
                    fn: "addChains",
                    args: [
                        [
                            {
                                caip2ChainId: "eip155:10",
                                assetRecoveryAddress:
                                    "0x1000000000000000000000000000000000000004",
                                accounts: [
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000003",
                                        childContractScope: 2,
                                    },
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000004",
                                        childContractScope: 0,
                                    },
                                    {
                                        accountAddress:
                                            "0x5000000000000000000000000000000000000005",
                                        childContractScope: 0,
                                    },
                                ],
                            },
                        ],
                    ],
                },
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:1",
                        [
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000004",
                                childContractScope: 2,
                            },
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000005",
                                childContractScope: 0,
                            },
                        ],
                    ],
                },
                {
                    fn: "removeAccounts",
                    args: [
                        "eip155:1",
                        [
                            "0x2000000000000000000000000000000000000002",
                            "0x2000000000000000000000000000000000000001",
                        ],
                    ],
                },
            ]);
        });
    });
    describe("Edge cases", () => {
        test("should add before removing for a full account replacement", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "addAccounts",
                    args: [
                        "eip155:1",
                        [
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000003",
                                childContractScope: 0,
                            },
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000004",
                                childContractScope: 2,
                            },
                        ],
                    ],
                },
                {
                    fn: "removeAccounts",
                    args: [
                        "eip155:1",
                        [
                            "0x2000000000000000000000000000000000000002",
                            "0x2000000000000000000000000000000000000001",
                        ],
                    ],
                },
            ]);
        });

        test("should handle completely empty onChain state", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "addChains",
                    args: [
                        [
                            {
                                caip2ChainId: "eip155:1",
                                assetRecoveryAddress:
                                    "0x1000000000000000000000000000000000000001",
                                accounts: [
                                    {
                                        accountAddress:
                                            "0x2000000000000000000000000000000000000001",
                                        childContractScope: 0,
                                    },
                                ],
                            },
                        ],
                    ],
                },
            ]);
        });
        test("should handle completely empty CSV state", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: "Status,Chain,Address,isFactory\n",
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            expect(
                result.updates.map(({ fn, args }) => ({ fn, args })),
            ).toEqual([
                {
                    fn: "removeChains",
                    args: [["eip155:1", "eip155:8453", "eip155:42161"]],
                },
            ]);
        });
        test("shoud handle account scope changes", async () => {
            const result = await generateFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
        });
    });

    describe("Chain Property Validation", () => {
        test("should block account planning on a recovery mismatch", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });

        test("should return a diagnostic only for the mismatched recovery address", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);

            expect(result.validationWarnings).toEqual([
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });

        test("should collect unknown Safeharbor Sheet chains as validation warnings", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                    ACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.validationWarnings).toEqual([
                {
                    code: "UNKNOWN_SHEET_CHAIN",
                    context: { chainName: "UNKNOWN" },
                },
            ]);
            expect(result.changes).toEqual([]);
        });
    });

    describe("Chain Details Duplicate Validation", () => {
        test("should collect chain metadata warnings in the reconciliation result", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                    ETHEREUM,eip155:2,0x1000000000000000000000000000000000000001
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.validationWarnings).toEqual([duplicateWarning]);
            expect(result.changes).toEqual([]);
        });
    });

    describe("Validation warning aggregation", () => {
        test("should block chain planning on on-chain normalization warnings", async () => {
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:137",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x6000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([unknownChainWarning]);
        });

        test("should collect warnings from every stage before planning updates", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            };
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                    ETHEREUM,eip155:2,0x1000000000000000000000000000000000000001
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:137",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x6000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                duplicateWarning,
                unknownChainWarning,
                {
                    code: "UNKNOWN_SHEET_CHAIN",
                    context: { chainName: "UNKNOWN" },
                },
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });
    });
});

test.each([
    {
        scenario:
            "a new EVM chain with a lowercase recovery address and blank metadata rows",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\n,,\nETHEREUM,eip155:1,0x8ba1f109551bd432803012645ac136ddd64dba72\n,,\n",
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedUpdates: [
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x8ba1f109551bd432803012645ac136ddd64dba72",
                            accounts: [
                                {
                                    accountAddress:
                                        "0x2000000000000000000000000000000000000001",
                                    childContractScope: 0,
                                },
                            ],
                        },
                    ],
                ],
                calldata: expect.stringMatching(/^0x[0-9a-f]+$/),
            },
        ],
    },
    {
        scenario: "a new EVM chain with a checksummed recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x8ba1f109551bD432803012645Ac136ddd64DBA72
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedUpdates: [
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                            accounts: [
                                {
                                    accountAddress:
                                        "0x2000000000000000000000000000000000000001",
                                    childContractScope: 0,
                                },
                            ],
                        },
                    ],
                ],
                calldata: expect.stringMatching(/^0x[0-9a-f]+$/),
            },
        ],
    },
    {
        scenario: "a new Solana chain preserving its exact recovery identifier",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: { chains: [] },
        expectedUpdates: [
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId:
                                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                            assetRecoveryAddress:
                                "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                            accounts: [
                                {
                                    accountAddress:
                                        "So11111111111111111111111111111111111111112",
                                    childContractScope: 0,
                                },
                            ],
                        },
                    ],
                ],
                calldata: expect.stringMatching(/^0x[0-9a-f]+$/),
            },
        ],
    },
    {
        scenario: "an EVM recovery-address case difference on a retained chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x8ba1f109551bd432803012645ac136ddd64dba72
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [],
    },
    {
        scenario: "blank metadata rows with an otherwise valid chain removal",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n,,\n",
        contractCSV: "Status,Chain,Address,isFactory\n",
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
        expectedUpdates: [
            {
                fn: "removeChains",
                args: [["eip155:1"]],
                calldata: expect.stringMatching(/^0x[0-9a-f]+$/),
            },
        ],
    },
])(
    "accepts $scenario",
    async ({ chainCSV, contractCSV, details, expectedUpdates }) => {
        const result = await generateFrom({ chainCSV, contractCSV, details });

        expect(result.updates).toEqual(expectedUpdates);
    },
);

test.each([
    {
        scenario:
            "an existing ETHEREUM chain with an undefined recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: undefined,
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing ETHEREUM chain with an null recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: null,
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing ETHEREUM chain with an empty recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an undefined recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: undefined,
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an null recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: null,
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an empty recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: "",
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario:
            "independent metadata and empty-account warnings before diffing",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            ETHEREUM,eip155:2,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            },
            {
                code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "a malformed recovery address on a new EVM chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,not-an-address
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "ETHEREUM",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        ],
    },
    {
        scenario: "an invalid recovery checksum on a new EVM chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x8Ba1f109551bD432803012645Ac136ddd64DBA72
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "ETHEREUM",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
        ],
    },
    {
        scenario: "a Solana recovery-address case mismatch",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "SOLANA",
                    onChainRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    sheetRecoveryAddress:
                        "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
        ],
    },
    {
        scenario:
            "incomplete unused metadata with an otherwise valid chain removal",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            BASE,eip155:8453,
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
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
        expectedWarnings: [
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
        scenario: "multiple incomplete rows without otherwise required updates",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            BASE,eip155:8453,
            ,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INCOMPLETE_CHAIN_METADATA",
                context: {
                    chainName: "BASE",
                    chainId: "eip155:8453",
                    missingFields: ["Asset Recovery Address"],
                },
            },
            {
                code: "INCOMPLETE_CHAIN_METADATA",
                context: {
                    chainName: "",
                    chainId: "eip155:1",
                    missingFields: ["Name"],
                },
            },
        ],
    },
    {
        scenario: "duplicate chain names",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            ETHEREUM,eip155:2,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
        expectedWarnings: [
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            },
        ],
    },
    {
        scenario: "duplicate chain IDs",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            OTHER,eip155:1,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
        expectedWarnings: [
            {
                code: "DUPLICATE_CHAIN_ID",
                context: {
                    chainId: "eip155:1",
                    firstChainName: "ETHEREUM",
                    duplicateChainName: "OTHER",
                },
            },
        ],
    },
    {
        scenario: "duplicate additions to an existing chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
        expectedWarnings: [
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0,
                    duplicateScope: 0,
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in a new chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 0,
                },
            },
        ],
    },
    {
        scenario: "conflicting desired scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
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
        expectedWarnings: [
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 2,
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts with no other differences",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 0n,
                },
            },
        ],
    },
    {
        scenario: "conflicting current scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 2n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 2n,
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts on a removed chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 0n,
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in both sources",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000002", 0n],
                        ["0x2000000000000000000000000000000000000002", 2n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0n,
                    duplicateScope: 2n,
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
        ],
    },
])(
    "returns diagnostics only for $scenario",
    async ({ chainCSV, contractCSV, details, expectedWarnings }) => {
        const result = await reconcileFrom({ chainCSV, contractCSV, details });
        expect(result.changes).toEqual([]);
        expect(result.validationWarnings).toEqual(expectedWarnings);
    },
);

test.each([
    {
        scenario: "replaces one account with two: [A] -> [B,C]",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE
        `,
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
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000002",
                            childContractScope: 0,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000003",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
        ],
    },
    {
        scenario: "replaces three accounts with one: [A,B,C] -> [D]",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                        ["0x2000000000000000000000000000000000000003", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000004",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    [
                        "0x2000000000000000000000000000000000000003",
                        "0x2000000000000000000000000000000000000002",
                        "0x2000000000000000000000000000000000000001",
                    ],
                ],
            },
        ],
    },
    {
        scenario: "removes before adding for a partial replacement",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                        ["0x2000000000000000000000000000000000000003", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000002"],
                ],
            },
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000004",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
        ],
    },
    {
        scenario: "ignores reordered equivalent accounts",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 2n],
                        ["0x2000000000000000000000000000000000000003", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [],
    },
    {
        scenario: "replaces the scope of the sole account",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
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
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
        ],
    },
    {
        scenario:
            "replaces every account scope without removing the new scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
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
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    [
                        "0x2000000000000000000000000000000000000002",
                        "0x2000000000000000000000000000000000000001",
                    ],
                ],
            },
        ],
    },
    {
        scenario: "replaces and reorders all three account scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                        ["0x2000000000000000000000000000000000000003", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000003",
                            childContractScope: 2,
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
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    [
                        "0x2000000000000000000000000000000000000003",
                        "0x2000000000000000000000000000000000000002",
                        "0x2000000000000000000000000000000000000001",
                    ],
                ],
            },
        ],
    },
    {
        scenario:
            "mixes a scope replacement with new and removed accounts: [A:0,B:0] -> [B:2,C:0]",
        snapshot: true,
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000002",
                            childContractScope: 2,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000003",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    [
                        "0x2000000000000000000000000000000000000002",
                        "0x2000000000000000000000000000000000000001",
                    ],
                ],
            },
        ],
    },
    {
        scenario:
            "isolates full and partial replacements across chains sharing an account address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            BASE,eip155:8453,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,BASE,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,BASE,0x2000000000000000000000000000000000000003,TRUE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
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
                {
                    caip2ChainId: "eip155:8453",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:8453",
                    ["0x2000000000000000000000000000000000000002"],
                ],
            },
            {
                fn: "addAccounts",
                args: [
                    "eip155:8453",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000003",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
        ],
    },
    {
        scenario: "reduces a retained account scope from 2 to 0",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 2n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
        ],
    },
    {
        scenario: "replaces FutureOnly scopes with both Sheet scope values",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,A,FALSE
            ACTIVE,ETHEREUM,B,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["A", 3n],
                        ["B", 3n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        { accountAddress: "A", childContractScope: 0 },
                        { accountAddress: "B", childContractScope: 2 },
                    ],
                ],
            },
            { fn: "removeAccounts", args: ["eip155:1", ["B", "A"]] },
        ],
    },
    {
        scenario: "replaces a sole account scope from 1 to 0",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 1n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
        ],
    },
    {
        scenario: "replaces a sole account scope from 1 to 2",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 1n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2,
                        },
                    ],
                ],
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
            },
        ],
    },
    {
        scenario:
            "treats EVM account case changes as exact string replacements",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0xa000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0xA000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000002", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0xA000000000000000000000000000000000000001"],
                ],
            },
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0xa000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
        ],
    },
    {
        scenario:
            "treats Solana account case changes as exact string replacements",
        snapshot: true,
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,so11111111111111111111111111111111111111112,FALSE
            ACTIVE,SOLANA,3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                        ["3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL", 0n],
                    ],
                },
            ],
        },
        expectedUpdates: [
            {
                fn: "removeAccounts",
                args: [
                    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    ["So11111111111111111111111111111111111111112"],
                ],
            },
            {
                fn: "addAccounts",
                args: [
                    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    [
                        {
                            accountAddress:
                                "so11111111111111111111111111111111111111112",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
        ],
    },
])(
    "$scenario",
    async ({ chainCSV, contractCSV, details, expectedUpdates, snapshot }) => {
        const result = await generateFrom({ chainCSV, contractCSV, details });
        expect(result.updates.map(({ fn, args }) => ({ fn, args }))).toEqual(
            expectedUpdates,
        );
        if (snapshot) {
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
        }
    },
);

const agreementInterface = new Interface(AGREEMENT_V3_ABI);

/**
 * Converts values decoded by ethers into snapshot-friendly JavaScript values.
 *
 * Ethers returns ABI tuples as Result objects with positional fields, while the
 * Agreement ABI knows the component names. Passing the matching ABI ParamType
 * lets snapshots show named structs such as accountAddress, childContractScope,
 * and caip2ChainId instead of opaque positional arrays.
 *
 * @param {*} value Value returned by ethers while decoding calldata.
 * @param {import("ethers").ParamType} param ABI parameter metadata for value.
 * @returns {*} Stable value suitable for inline object snapshots.
 */
function normalizeDecodedValue(value, param) {
    if (param.name === "childContractScope") {
        return Number(value);
    }

    if (typeof value === "bigint") {
        return value.toString();
    }

    if (param.baseType === "array") {
        return value.map((item) =>
            normalizeDecodedValue(item, param.arrayChildren),
        );
    }

    if (param.baseType === "tuple") {
        return Object.fromEntries(
            param.components.map((component, index) => [
                component.name,
                normalizeDecodedValue(value[index], component),
            ]),
        );
    }

    return value;
}

/**
 * Builds the stable payload snapshot for generated Safe Harbor updates.
 *
 * The raw calldata is preserved so the snapshot pins the exact executable
 * bytes. The same calldata is decoded through the Agreement ABI to check the
 * function name and every normalized argument against the update, without EVM
 * execution. The named arguments remain in the snapshot for review.
 *
 * @param {Array<{fn: string, args: Array<*>, calldata: string}>} updates Generated payload updates.
 * @returns {Array<{calldata: string, decodedName: string, decodedArgs: Array<*>}>}
 */
function payloadSnapshot(updates) {
    return updates.map((update, index) => {
        const decoded = agreementInterface.parseTransaction({
            data: update.calldata,
        });
        assert.ok(decoded, `Unable to decode payload update ${index}`);
        assert.strictEqual(decoded.name, update.fn);
        const decodedArgs = decoded.fragment.inputs.map((input, inputIndex) =>
            normalizeDecodedValue(decoded.args[inputIndex], input),
        );
        assert.deepStrictEqual(decodedArgs, update.args);

        return {
            calldata: update.calldata,
            decodedName: decoded.name,
            decodedArgs,
        };
    });
}
