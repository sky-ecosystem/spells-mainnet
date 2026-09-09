import { test, expect, describe, vi, beforeEach, afterEach } from "vitest";
import assert from "node:assert";
import { Contract, Interface, JsonRpcProvider } from "ethers";
import { generatePayload } from "../src/generation/index.js";
import { reconcile } from "../src/reconciliation/index.js";
import { createAgreementReader } from "../src/agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";
import { AGREEMENT_V3_ABI } from "../src/agreement/abis.js";

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

async function generateFrom({ chainCSV, contractCSV, details }) {
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
        getAgreementState: createAgreementReader({ provider }),
        getSheetState,
        getSheetChainDetails,
    });
    expect(encodeSpy).not.toHaveBeenCalled();
    if (report.validationWarnings.length > 0) {
        expect(report.changes).toEqual([]);
    } else {
        expect(report.changes).toBeInstanceOf(Array);
    }
    const payload =
        report.validationWarnings.length > 0
            ? { updates: [], solidityCode: "" }
            : generatePayload(report.changes);
    const result = {
        ...payload,
        validationWarnings: report.validationWarnings,
    };
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    payloadSnapshot(result.updates);
    return result;
}

// Static synthetic fixtures shaped like production EVM and Solana identifiers.
const RECOVERY = {
    ETH: "0x1000000000000000000000000000000000000001",
    OP: "0x1000000000000000000000000000000000000004",
    SOL: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
    MISMATCH: "0x10000000000000000000000000000000000000ff",
};

const ACCOUNT = {
    ETH2: "0x2000000000000000000000000000000000000002",
    ETH3: "0x2000000000000000000000000000000000000003",
    BASE2: "0x3000000000000000000000000000000000000002",
    ARB1: "0x4000000000000000000000000000000000000001",
    ARB3: "0x4000000000000000000000000000000000000003",
    OP1: "0x5000000000000000000000000000000000000001",
    OP2: "0x5000000000000000000000000000000000000002",
    OPF: "0x5000000000000000000000000000000000000003",
    OPR1: "0x5000000000000000000000000000000000000004",
    OPR2: "0x5000000000000000000000000000000000000005",
    SOL1: "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
};

describe("generatePayload", () => {
    describe("No changes scenario", () => {
        test("should generate no updates when onChain and CSV data match", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            assert.deepStrictEqual(result.validationWarnings, []);
        });
    });

    describe("Account addition scenarios", () => {
        test("should generate addAccounts updates when new accounts are added to existing chains", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000002,TRUE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            assert.strictEqual(result.updates.length, 2);
            const addAccountsUpdates = result.updates.filter(
                (u) => u.fn === "addAccounts",
            );
            assert.strictEqual(addAccountsUpdates.length, 2);
            const ethereumUpdate = addAccountsUpdates.find(
                (u) => u.args[0] === "eip155:1",
            );
            assert.ok(ethereumUpdate);
            assert.deepStrictEqual(ethereumUpdate.args[1], [
                { accountAddress: ACCOUNT.ETH3, childContractScope: 0 },
            ]);
            const baseUpdate = addAccountsUpdates.find(
                (u) => u.args[0] === "eip155:8453",
            );
            assert.ok(baseUpdate);
            assert.deepStrictEqual(baseUpdate.args[1], [
                { accountAddress: ACCOUNT.BASE2, childContractScope: 2 },
            ]);
        });
    });
    describe("Account removal scenarios", () => {
        test("should generate removeAccounts updates when accounts are removed", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            assert.strictEqual(result.updates.length, 2);
            const removeAccountsUpdates = result.updates.filter(
                (u) => u.fn === "removeAccounts",
            );
            assert.strictEqual(removeAccountsUpdates.length, 2);
            const ethereumUpdate = removeAccountsUpdates.find(
                (u) => u.args[0] === "eip155:1",
            );
            assert.ok(ethereumUpdate);
            assert.deepStrictEqual(ethereumUpdate.args[1], [ACCOUNT.ETH2]);
            const arbitrumUpdate = removeAccountsUpdates.find(
                (u) => u.args[0] === "eip155:42161",
            );
            assert.ok(arbitrumUpdate);
            assert.deepStrictEqual(arbitrumUpdate.args[1], [ACCOUNT.ARB1]);
        });
    });
    describe("Chain addition scenarios", () => {
        test("should generate addChains updates when new chains are introduced", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000001,FALSE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000002,TRUE\nACTIVE,SOLANA,3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL,FALSE\n",
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
            assert.strictEqual(result.updates.length, 1);
            const addChainsUpdates = result.updates.filter(
                (u) => u.fn === "addChains",
            );
            assert.strictEqual(addChainsUpdates.length, 1);
            const newChains = addChainsUpdates[0].args[0];
            assert.strictEqual(newChains.length, 2);
            const optimismChain = newChains.find(
                (c) => c.caip2ChainId === "eip155:10",
            );
            assert.ok(optimismChain);
            assert.strictEqual(optimismChain.assetRecoveryAddress, RECOVERY.OP);
            assert.strictEqual(optimismChain.accounts.length, 2);
            assert.deepStrictEqual(optimismChain.accounts, [
                { accountAddress: ACCOUNT.OP1, childContractScope: 0 },
                { accountAddress: ACCOUNT.OP2, childContractScope: 2 },
            ]);
            const solanaChain = newChains.find(
                (c) =>
                    c.caip2ChainId ===
                    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            );
            assert.ok(solanaChain);
            assert.strictEqual(solanaChain.assetRecoveryAddress, RECOVERY.SOL);
            assert.strictEqual(solanaChain.accounts.length, 1);
            assert.deepStrictEqual(solanaChain.accounts, [
                { accountAddress: ACCOUNT.SOL1, childContractScope: 0 },
            ]);
        });
    });
    describe("Chain removal scenarios", () => {
        test("should generate removeChains updates when chains are removed", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\n",
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
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.fn === "removeChains",
            );
            assert.strictEqual(removeChainsUpdates.length, 1);
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 2);
            assert.ok(chainIdsToRemove.includes("eip155:8453"));
            assert.ok(chainIdsToRemove.includes("eip155:42161"));
        });
    });
    describe("Complex mixed scenarios", () => {
        test("should handle simultaneous chain additions, removals, and account changes", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000003,TRUE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000001,FALSE\n",
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
            assert.strictEqual(result.updates.length, 5);
            const chainUpdates = result.updates.filter(
                (u) => u.fn === "removeChains" || u.fn === "addChains",
            );
            const accountUpdates = result.updates.filter(
                (u) => u.fn === "removeAccounts" || u.fn === "addAccounts",
            );
            assert.ok(chainUpdates.length > 0, "Should have chain updates");
            assert.ok(accountUpdates.length > 0, "Should have account updates");
            const removeChainUpdate = result.updates.find(
                (u) => u.fn === "removeChains",
            );
            assert.strictEqual(removeChainUpdate.args[0].length, 1);
            assert.ok(removeChainUpdate.args[0].includes("eip155:8453"));
            const addChainUpdate = result.updates.find(
                (u) => u.fn === "addChains",
            );
            assert.ok(addChainUpdate.args[0].length, 2);
            const newChain = addChainUpdate.args[0].find(
                (c) => c.caip2ChainId === "eip155:10",
            );
            assert.ok(newChain);
            // Assert that removeAccounts for eip155:1 appears before addAccounts for eip155:1
            const removeAccountIndex = result.updates.findIndex(
                (u) => u.fn === "removeAccounts" && u.args[0] === "eip155:1",
            );
            const addAccountIndex = result.updates.findIndex(
                (u) => u.fn === "addAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(
                removeAccountIndex > -1 && addAccountIndex > -1,
                "Both removeAccounts and addAccounts updates for eip155:1 should exist",
            );
            assert.ok(
                removeAccountIndex < addAccountIndex,
                "removeAccounts for eip155:1 should appear before addAccounts for eip155:1",
            );
            const removeAccountUpdate = result.updates[removeAccountIndex];
            assert.ok(removeAccountUpdate.args[1].length, 1);
            assert.ok(removeAccountUpdate.args[1].includes(ACCOUNT.ETH2));
            const addAccountUpdate = result.updates[addAccountIndex];
            assert.ok(addAccountUpdate.args[1].length, 1);
            assert.deepStrictEqual(addAccountUpdate.args[1], [
                { accountAddress: ACCOUNT.ETH3, childContractScope: 0 },
            ]);
            const addAccountUpdate2 = result.updates.find(
                (u) => u.fn === "addAccounts" && u.args[0] === "eip155:42161",
            );
            assert.ok(addAccountUpdate2.args[1].length, 1);
            assert.deepStrictEqual(addAccountUpdate2.args[1], [
                { accountAddress: ACCOUNT.ARB3, childContractScope: 2 },
            ]);

            expect(result.validationWarnings).toEqual([]);
        });
        test("should preserve childContractScope values correctly in complex scenarios", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000005,FALSE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000003,TRUE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000004,FALSE\nACTIVE,OPTIMISM,0x5000000000000000000000000000000000000005,FALSE\n",
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
            assert.strictEqual(result.updates.length, 4);
            const addChainUpdate = result.updates.find(
                (u) => u.fn === "addChains",
            );
            assert.ok(addChainUpdate);
            const optimismChain = addChainUpdate.args[0].find(
                (c) => c.caip2ChainId === "eip155:10",
            );
            assert.ok(optimismChain);
            const factoryAccount = optimismChain.accounts.find(
                (a) => a.accountAddress === ACCOUNT.OPF,
            );
            const normalAccounts = optimismChain.accounts.filter((a) =>
                [ACCOUNT.OPR1, ACCOUNT.OPR2].includes(a.accountAddress),
            );
            assert.strictEqual(factoryAccount.childContractScope, 2);
            assert.strictEqual(normalAccounts.length, 2);
            assert.ok(normalAccounts.every((a) => a.childContractScope === 0));

            const removeAccountFromEthereumUpdate = result.updates.find(
                (u) => u.fn === "removeAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(removeAccountFromEthereumUpdate);

            const addAccountToEthereumUpdate = result.updates.find(
                (u) => u.fn === "addAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(addAccountToEthereumUpdate);
        });
    });
    describe("Edge cases", () => {
        test("should add before removing for a full account replacement", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            const ethereumUpdates = result.updates.filter(
                (update) => update.args[0] === "eip155:1",
            );

            expect(ethereumUpdates.map((update) => update.fn)).toEqual([
                "addAccounts",
                "removeAccounts",
            ]);
        });

        test("should add before removing for a sole-account scope change", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,TRUE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            const baseUpdates = result.updates.filter(
                (update) => update.args[0] === "eip155:8453",
            );

            expect(baseUpdates.map((update) => update.fn)).toEqual([
                "addAccounts",
                "removeAccounts",
            ]);
        });

        test("should handle completely empty onChain state", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
                details: {
                    chains: [],
                },
            });
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 1);
            const addChainsUpdates = result.updates.filter(
                (u) => u.fn === "addChains",
            );
            assert.strictEqual(addChainsUpdates.length, 1);
            const removeUpdates = result.updates.filter((u) =>
                u.fn.includes("remove"),
            );
            assert.strictEqual(removeUpdates.length, 0);
        });
        test("should handle completely empty CSV state", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
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
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.fn === "removeChains",
            );
            assert.strictEqual(removeChainsUpdates.length, 1);
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 3);
            assert.ok(chainIdsToRemove.includes("eip155:1"));
            assert.ok(chainIdsToRemove.includes("eip155:8453"));
            assert.ok(chainIdsToRemove.includes("eip155:42161"));
        });
        test("shoud handle account scope changes", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
        test("should block account updates before encoding on a recovery mismatch", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\n",
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

            expect(result.updates).toEqual([]);
            expect(result.solidityCode).toBe("");
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
            expect(encodeSpy).not.toHaveBeenCalled();
        });

        test("should return a diagnostic only for the mismatched recovery address", async () => {
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\n",
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

            expect(result.updates).toEqual([]);
            expect(result.solidityCode).toBe("");
            expect(encodeSpy).not.toHaveBeenCalled();

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
            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\nACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE\n",
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
            expect(result.updates).toEqual([]);
            expect(result.solidityCode).toBe("");
            expect(encodeSpy).not.toHaveBeenCalled();
        });
    });

    describe("Chain Details Duplicate Validation", () => {
        test("should collect chain metadata warnings in the payload result", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: { chainName: "ETHEREUM" },
            };

            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000001\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE\nACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE\n",
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
            expect(result.updates).toEqual([]);
            expect(result.solidityCode).toBe("");
            expect(encodeSpy).not.toHaveBeenCalled();
        });
    });

    describe("Validation warning aggregation", () => {
        test("should block chain updates on on-chain normalization warnings", async () => {
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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

            expect(result).toEqual({
                updates: [],
                solidityCode: "",
                validationWarnings: [unknownChainWarning],
            });
            expect(encodeSpy).not.toHaveBeenCalled();
        });

        test("should collect warnings from every stage before encoding updates", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: { chainName: "ETHEREUM" },
            };
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await generateFrom({
                chainCSV:
                    "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,0x1000000000000000000000000000000000000002\nARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003\nOPTIMISM,eip155:10,0x1000000000000000000000000000000000000004\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000001\n",
                contractCSV:
                    "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE\n",
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

            expect(result).toEqual({
                updates: [],
                solidityCode: "",
                validationWarnings: [
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
                ],
            });
            expect(encodeSpy).not.toHaveBeenCalled();
        });
    });
});

test.each([
    {
        scenario:
            "a new EVM chain with a lowercase recovery address and blank metadata rows",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\n,,\nETHEREUM,eip155:1,0x8ba1f109551bd432803012645ac136ddd64dba72\n,,\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x8ba1f109551bD432803012645Ac136ddd64DBA72\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x8ba1f109551bd432803012645ac136ddd64dba72\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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

        expect(result.validationWarnings).toEqual([]);
        expect(result.updates).toEqual(expectedUpdates);
        if (expectedUpdates.length === 0) {
            expect(result.solidityCode).toBe("");
        } else {
            for (const update of result.updates) {
                expect(result.solidityCode).toContain(update.calldata.slice(2));
            }
        }
    },
);

test.each([
    {
        scenario:
            "an existing ETHEREUM chain with an undefined recovery address",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE\n",
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
        scenario: "validation warnings before diffing an invalid new account",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002\n",
        contractCSV: "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,,FALSE\n",
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "a malformed recovery address on a new EVM chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,not-an-address\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x8Ba1f109551bD432803012645Ac136ddd64DBA72\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nSOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nBASE,eip155:8453,\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nBASE,eip155:8453,\n,eip155:1,0x1000000000000000000000000000000000000001\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
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
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "duplicate chain IDs",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nOTHER,eip155:1,0x1000000000000000000000000000000000000002\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
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
            { code: "DUPLICATE_CHAIN_ID", context: { chainId: "eip155:1" } },
        ],
    },
    {
        scenario: "duplicate additions to an existing chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
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
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in a new chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                },
            },
        ],
    },
    {
        scenario: "conflicting desired scopes",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\n",
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
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts with no other differences",
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
                },
            },
        ],
    },
    {
        scenario: "conflicting current scopes",
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
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts on a removed chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
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
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in both sources",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\n",
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
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                },
            },
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                },
            },
        ],
    },
])(
    "returns diagnostics only for $scenario",
    async ({ chainCSV, contractCSV, details, expectedWarnings }) => {
        await expect(
            generateFrom({ chainCSV, contractCSV, details }),
        ).resolves.toEqual({
            updates: [],
            solidityCode: "",
            validationWarnings: expectedWarnings,
        });
        expect(encodeSpy).not.toHaveBeenCalled();
    },
);

test.each([
    {
        scenario: "replaces one account with two: [A] -> [B,C]",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,FALSE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000004,TRUE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\n",
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
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\n",
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
])("$scenario", async ({ chainCSV, contractCSV, details, expectedUpdates }) => {
    const result = await generateFrom({ chainCSV, contractCSV, details });
    expect(result.validationWarnings).toEqual([]);
    expect(result.updates.map(({ fn, args }) => ({ fn, args }))).toEqual(
        expectedUpdates,
    );
    if (expectedUpdates.length === 0) {
        expect(result.solidityCode).toBe("");
    } else {
        for (const update of result.updates) {
            expect(result.solidityCode).toContain(update.calldata.slice(2));
        }
    }
});

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
 * @param {import("ethers").ParamType} [param] ABI parameter metadata for value.
 * @returns {*} Stable value suitable for inline object snapshots.
 */
function normalizeDecodedValue(value, param) {
    if (param?.name === "childContractScope") {
        return Number(value);
    }

    if (typeof value === "bigint") {
        return value.toString();
    }

    if (!value || typeof value !== "object") {
        return value;
    }

    if (param?.baseType === "array") {
        return value.map((item) =>
            normalizeDecodedValue(item, param.arrayChildren),
        );
    }

    if (param?.baseType === "tuple") {
        return Object.fromEntries(
            param.components.map((component, index) => [
                component.name,
                normalizeDecodedValue(value[index], component),
            ]),
        );
    }

    if (Array.isArray(value)) {
        return value.map((item) => normalizeDecodedValue(item));
    }

    return Object.fromEntries(
        Object.entries(value)
            .filter(([key]) => Number.isNaN(Number(key)))
            .map(([key, nestedValue]) => [
                key,
                normalizeDecodedValue(nestedValue),
            ]),
    );
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
