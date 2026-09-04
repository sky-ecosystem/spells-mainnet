import { test, expect, describe, vi, beforeEach, afterEach } from "vitest";
import assert from "node:assert";
import { Interface } from "ethers";
import { generatePayload } from "../src/generatePayload.js";
import { AGREEMENT_V3_ABI } from "../src/abis.js";

// Mock the dependencies
vi.mock("../src/fetchCSV.js", async (importOriginal) => {
    const actual = await importOriginal();
    return {
        ...actual,
        getNormalizedContractsInScopeFromCSV: vi.fn(),
        getChainDetailsFromCSV: vi.fn(),
    };
});
vi.mock("../src/fetchOnchain.js");
vi.mock("fs", () => ({
    writeFileSync: vi.fn(),
}));

import {
    getNormalizedContractsInScopeFromCSV,
    getChainDetailsFromCSV,
} from "../src/fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "../src/fetchOnchain.js";

let consoleWarnSpy;
let consoleErrorSpy;

// Static synthetic fixtures shaped like production EVM and Solana identifiers.
const RECOVERY = {
    ETH: "0x1000000000000000000000000000000000000001",
    BASE: "0x1000000000000000000000000000000000000002",
    ARB: "0x1000000000000000000000000000000000000003",
    OP: "0x1000000000000000000000000000000000000004",
    SOL: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
    MISMATCH: "0x10000000000000000000000000000000000000ff",
};

const ACCOUNT = {
    ETH1: "0x2000000000000000000000000000000000000001",
    ETH2: "0x2000000000000000000000000000000000000002",
    ETH3: "0x2000000000000000000000000000000000000003",
    ETHF: "0x2000000000000000000000000000000000000004",
    ETHR: "0x2000000000000000000000000000000000000005",
    BASE1: "0x3000000000000000000000000000000000000001",
    BASE2: "0x3000000000000000000000000000000000000002",
    ARB1: "0x4000000000000000000000000000000000000001",
    ARB2: "0x4000000000000000000000000000000000000002",
    ARB3: "0x4000000000000000000000000000000000000003",
    OP1: "0x5000000000000000000000000000000000000001",
    OP2: "0x5000000000000000000000000000000000000002",
    OPF: "0x5000000000000000000000000000000000000003",
    OPR1: "0x5000000000000000000000000000000000000004",
    OPR2: "0x5000000000000000000000000000000000000005",
    SOL1: "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
    UNKNOWN: "0x6000000000000000000000000000000000000001",
};

const CHAIN_DETAILS = {
    caip2ChainId: {
        ETHEREUM: "eip155:1",
        BASE: "eip155:8453",
        ARBITRUM: "eip155:42161",
        OPTIMISM: "eip155:10",
        SOLANA: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
    },
    assetRecoveryAddress: {
        ETHEREUM: RECOVERY.ETH,
        BASE: RECOVERY.BASE,
        ARBITRUM: RECOVERY.ARB,
        OPTIMISM: RECOVERY.OP,
        SOLANA: RECOVERY.SOL,
    },
    name: {
        "eip155:1": "ETHEREUM",
        "eip155:8453": "BASE",
        "eip155:42161": "ARBITRUM",
        "eip155:10": "OPTIMISM",
        "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "SOLANA",
    },
};

function mockOnChainState(onChainState, validationWarnings = []) {
    getNormalizedDataFromOnchainState.mockResolvedValue({
        onChainState,
        validationWarnings,
    });
}

describe("inspectPayload E2E Tests", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        consoleWarnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
        consoleErrorSpy = vi
            .spyOn(console, "error")
            .mockImplementation(() => {});
        getChainDetailsFromCSV.mockResolvedValue({
            chainDetails: CHAIN_DETAILS,
            validationWarnings: [],
        });
    });

    afterEach(() => {
        try {
            expect(consoleErrorSpy).not.toHaveBeenCalled();
        } finally {
            consoleWarnSpy.mockRestore();
            consoleErrorSpy.mockRestore();
        }
    });

    const INITIAL_ONCHAIN_STATE = {
        ETHEREUM: {
            accounts: [
                { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
            ],
            assetRecoveryAddress: RECOVERY.ETH,
        },
        BASE: {
            accounts: [
                { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
            ],
            assetRecoveryAddress: RECOVERY.BASE,
        },
        ARBITRUM: {
            accounts: [
                { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
            ],
            assetRecoveryAddress: RECOVERY.ARB,
        },
    };
    async function generateFrom(
        csvState,
        onChainState = INITIAL_ONCHAIN_STATE,
    ) {
        mockOnChainState(onChainState);
        getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvState);
        return generatePayload("");
    }

    describe("No changes scenario", () => {
        test("should generate no updates when onchain and CSV data match", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);

            // Assert - should have empty result since no changes needed
            assert.strictEqual(result.updates.length, 0);
            assert.strictEqual(result.solidityCode, "");
            assert.deepStrictEqual(result.validationWarnings, []);
        });
    });

    describe("Account addition scenarios", () => {
        test("should generate addAccounts updates when new accounts are added to existing chains", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                    { accountAddress: ACCOUNT.ETH3, childContractScope: 0 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.BASE2, childContractScope: 2 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 2);
            const addAccountsUpdates = result.updates.filter(
                (u) => u.function === "addAccounts",
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
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 2);
            const removeAccountsUpdates = result.updates.filter(
                (u) => u.function === "removeAccounts",
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
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
                OPTIMISM: [
                    { accountAddress: ACCOUNT.OP1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.OP2, childContractScope: 2 },
                ],
                SOLANA: [
                    { accountAddress: ACCOUNT.SOL1, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 1);
            const addChainsUpdates = result.updates.filter(
                (u) => u.function === "addChains",
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
        test("should reject adding a new chain without accounts", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
                OPTIMISM: [],
            };

            await assert.rejects(
                () => generateFrom(csvData),
                /Cannot add chain 'OPTIMISM' without accounts/,
            );
            expect(consoleErrorSpy).toHaveBeenCalledWith(
                "Error generating update payload:",
                expect.objectContaining({
                    message: "Cannot add chain 'OPTIMISM' without accounts",
                }),
            );
            consoleErrorSpy.mockClear();
        });
    });
    describe("Chain removal scenarios", () => {
        test("should generate removeChains updates when chains are removed", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.function === "removeChains",
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
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH3, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB3, childContractScope: 2 },
                ],
                OPTIMISM: [
                    { accountAddress: ACCOUNT.OP1, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 5);
            const chainUpdates = result.updates.filter(
                (u) =>
                    u.function === "removeChains" || u.function === "addChains",
            );
            const accountUpdates = result.updates.filter(
                (u) =>
                    u.function === "removeAccounts" ||
                    u.function === "addAccounts",
            );
            assert.ok(chainUpdates.length > 0, "Should have chain updates");
            assert.ok(accountUpdates.length > 0, "Should have account updates");
            const removeChainUpdate = result.updates.find(
                (u) => u.function === "removeChains",
            );
            assert.strictEqual(removeChainUpdate.args[0].length, 1);
            assert.ok(removeChainUpdate.args[0].includes("eip155:8453"));
            const addChainUpdate = result.updates.find(
                (u) => u.function === "addChains",
            );
            assert.ok(addChainUpdate.args[0].length, 2);
            const newChain = addChainUpdate.args[0].find(
                (c) => c.caip2ChainId === "eip155:10",
            );
            assert.ok(newChain);
            // Assert that removeAccounts for eip155:1 appears before addAccounts for eip155:1
            const removeAccountIndex = result.updates.findIndex(
                (u) =>
                    u.function === "removeAccounts" && u.args[0] === "eip155:1",
            );
            const addAccountIndex = result.updates.findIndex(
                (u) => u.function === "addAccounts" && u.args[0] === "eip155:1",
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
                (u) =>
                    u.function === "addAccounts" &&
                    u.args[0] === "eip155:42161",
            );
            assert.ok(addAccountUpdate2.args[1].length, 1);
            assert.deepStrictEqual(addAccountUpdate2.args[1], [
                { accountAddress: ACCOUNT.ARB3, childContractScope: 2 },
            ]);

            // Assert no warnings were logged
            const hasWarnings = consoleWarnSpy.mock.calls.some(
                (call) => call[0].includes("‼️") || call[0].includes("⚠️"),
            );
            assert.ok(
                !hasWarnings,
                "Console should not contain warning markers (‼️ or ⚠️)",
            );
        });
        test("should preserve childContractScope values correctly in complex scenarios", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETHF, childContractScope: 2 },
                    { accountAddress: ACCOUNT.ETHR, childContractScope: 0 },
                ],
                OPTIMISM: [
                    { accountAddress: ACCOUNT.OPF, childContractScope: 2 },
                    { accountAddress: ACCOUNT.OPR1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.OPR2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 4);
            const addChainUpdate = result.updates.find(
                (u) => u.function === "addChains",
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
                (u) =>
                    u.function === "removeAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(removeAccountFromEthereumUpdate);

            const addAccountToEthereumUpdate = result.updates.find(
                (u) => u.function === "addAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(addAccountToEthereumUpdate);
        });
    });
    describe("Edge cases", () => {
        test("should reject an existing chain without desired accounts", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            await assert.rejects(
                () => generateFrom(csvData),
                /Chain 'BASE' must be removed instead of configured without accounts/,
            );
            expect(consoleErrorSpy).toHaveBeenCalledWith(
                "Error generating update payload:",
                expect.objectContaining({
                    message:
                        "Chain 'BASE' must be removed instead of configured without accounts",
                }),
            );
            consoleErrorSpy.mockClear();
        });

        test("should add before removing for a full account replacement", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH3, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETHF, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            const ethereumUpdates = result.updates.filter(
                (update) => update.args[0] === "eip155:1",
            );

            expect(ethereumUpdates.map((update) => update.function)).toEqual([
                "addAccounts",
                "removeAccounts",
            ]);
        });

        test("should add before removing for a sole-account scope change", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 2 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            const baseUpdates = result.updates.filter(
                (update) => update.args[0] === "eip155:8453",
            );

            expect(baseUpdates.map((update) => update.function)).toEqual([
                "addAccounts",
                "removeAccounts",
            ]);
        });

        test("should handle completely empty onchain state", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                ],
            };
            const result = await generateFrom(csvData, {});
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 1);
            const addChainsUpdates = result.updates.filter(
                (u) => u.function === "addChains",
            );
            assert.strictEqual(addChainsUpdates.length, 1);
            const removeUpdates = result.updates.filter((u) =>
                u.function.includes("remove"),
            );
            assert.strictEqual(removeUpdates.length, 0);
        });
        test("should handle completely empty CSV state", async () => {
            const result = await generateFrom({});
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.function === "removeChains",
            );
            assert.strictEqual(removeChainsUpdates.length, 1);
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 3);
            assert.ok(chainIdsToRemove.includes("eip155:1"));
            assert.ok(chainIdsToRemove.includes("eip155:8453"));
            assert.ok(chainIdsToRemove.includes("eip155:42161"));
        });
        test("shoud handle account scope changes", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 2 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);
            expect(payloadSnapshot(result.updates)).toMatchSnapshot();
        });
    });

    describe("Chain Property Validation", () => {
        test("should log a warning when asset recovery addresses mismatch", async () => {
            // Arrange
            // Create a specific on-chain state for this test with a mismatch
            const onChainStateWithMismatch = {
                ETHEREUM: {
                    accounts: [
                        { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    ],
                    assetRecoveryAddress: RECOVERY.MISMATCH, // Mismatch
                },
                BASE: {
                    accounts: [
                        {
                            accountAddress: ACCOUNT.BASE1,
                            childContractScope: 0,
                        },
                    ],
                    assetRecoveryAddress: RECOVERY.BASE, // Match
                },
            };

            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(
                csvData,
                onChainStateWithMismatch,
            );

            // Assert
            const wasCalledWithMismatchWarning = consoleWarnSpy.mock.calls.some(
                (call) =>
                    call[0].includes("Asset Recovery Address mismatch") &&
                    call[0].includes("ETHEREUM") &&
                    call[0].includes(`On-chain: ${RECOVERY.MISMATCH}`) &&
                    call[0].includes(`CSV:      ${RECOVERY.ETH}`),
            );

            assert.ok(
                wasCalledWithMismatchWarning,
                "console.warn was not called with the expected mismatch message for ETHEREUM",
            );
            assert.ok(
                result.validationWarnings.some((warning) =>
                    warning.includes("Asset Recovery Address mismatch"),
                ),
            );

            const wasCalledForBase = consoleWarnSpy.mock.calls.some((call) =>
                call[0].includes("BASE"),
            );

            assert.ok(
                !wasCalledForBase,
                "console.warn should not be called for BASE as addresses match",
            );
        });

        test("should collect unknown CSV chains as validation warnings", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
                UNKNOWN: [
                    { accountAddress: ACCOUNT.UNKNOWN, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);

            expect(result.validationWarnings).toHaveLength(1);
            expect(result.validationWarnings[0]).toContain(
                "Unknown chain details in CSV: name='UNKNOWN'",
            );
        });
    });

    describe("Chain Details Duplicate Validation", () => {
        test("should collect chain metadata warnings in the payload result", async () => {
            const duplicateWarning =
                "⚠️  Warning: Duplicate chain name found in CSV: ETHEREUM ⚠️";
            getChainDetailsFromCSV.mockResolvedValue({
                chainDetails: CHAIN_DETAILS,
                validationWarnings: [duplicateWarning],
            });
            const csvData = {
                ETHEREUM: [
                    { accountAddress: ACCOUNT.ETH1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ETH2, childContractScope: 2 },
                ],
                BASE: [
                    { accountAddress: ACCOUNT.BASE1, childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: ACCOUNT.ARB1, childContractScope: 0 },
                    { accountAddress: ACCOUNT.ARB2, childContractScope: 0 },
                ],
            };

            const result = await generateFrom(csvData);

            expect(result.validationWarnings).toEqual([duplicateWarning]);
        });
    });
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
 * bytes. The same calldata is decoded through the Agreement ABI to prove those
 * bytes map back to the expected function name and named arguments.
 *
 * @param {Array<{function: string, calldata: string}>} updates Generated payload updates.
 * @returns {Array<{calldata: string, decodedName: string, decodedArgs: Array<*>}>}
 */
function payloadSnapshot(updates) {
    return updates.map((update, index) => {
        const decoded = agreementInterface.parseTransaction({
            data: update.calldata,
        });
        assert.ok(decoded, `Unable to decode payload update ${index}`);
        assert.strictEqual(decoded.name, update.function);

        return {
            calldata: update.calldata,
            decodedName: decoded.name,
            decodedArgs: decoded.fragment.inputs.map((input, inputIndex) =>
                normalizeDecodedValue(decoded.args[inputIndex], input),
            ),
        };
    });
}
