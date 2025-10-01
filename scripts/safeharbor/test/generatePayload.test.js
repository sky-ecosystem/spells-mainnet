import { test, describe, vi, beforeEach } from "vitest";
import assert from "node:assert";
import { generatePayload } from "../src/generatePayload.js";
import { MULTICALL_ADDRESS } from "../src/constants.js";

// Mock the dependencies
vi.mock("../src/fetchCSV.js");
vi.mock("../src/fetchOnchain.js");
vi.mock("fs", () => ({
    writeFileSync: vi.fn(),
}));

import {
    getNormalizedContractsInScopeFromCSV,
    getChainDetailsFromCSV,
} from "../src/fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "../src/fetchOnchain.js";

const CHAIN_DETAILS = {
    caip2ChainId: {
        ETHEREUM: "eip155:1",
        GNOSIS: "eip155:100",
        ARBITRUM: "eip155:42161",
        OPTIMISM: "eip155:10",
        POLYGON: "eip155:137",
    },
    assetRecoveryAddress: {
        ETHEREUM: "0xETHEREUM_RECOVERY_ADDRESS",
        GNOSIS: "0xGNOSIS_RECOVERY_ADDRESS",
        ARBITRUM: "0xARBITRUM_RECOVERY_ADDRESS",
        OPTIMISM: "0xOPTIMISM_RECOVERY_ADDRESS",
        POLYGON: "0xPOLYGON_RECOVERY_ADDRESS",
    },
    name: {
        "eip155:1": "ETHEREUM",
        "eip155:100": "GNOSIS",
        "eip155:42161": "ARBITRUM",
        "eip155:10": "OPTIMISM",
        "eip155:137": "POLYGON",
    },
};

describe("inspectPayload E2E Tests", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        getChainDetailsFromCSV.mockResolvedValue(CHAIN_DETAILS);
    });

    // Test Fixtures - UPDATED to match new on-chain data structure
    const INITIAL_ONCHAIN_STATE = {
        ETHEREUM: {
            accounts: [
                { accountAddress: "0xA1", childContractScope: 0 },
                { accountAddress: "0xA2", childContractScope: 2 },
            ],
            assetRecoveryAddress: "0xETHEREUM_RECOVERY_ADDRESS",
        },
        GNOSIS: {
            accounts: [{ accountAddress: "0xB1", childContractScope: 0 }],
            assetRecoveryAddress: "0xGNOSIS_RECOVERY_ADDRESS",
        },
        ARBITRUM: {
            accounts: [
                { accountAddress: "0xC1", childContractScope: 0 },
                { accountAddress: "0xC2", childContractScope: 0 },
            ],
            assetRecoveryAddress: "0xARBITRUM_RECOVERY_ADDRESS",
        },
    };

    describe("No changes scenario", () => {
        test("should generate no updates when onchain and CSV data match", async () => {
            // Arrange - CSV data matches onchain exactly
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
                GNOSIS: [{ accountAddress: "0xB1", childContractScope: 0 }],
                ARBITRUM: [
                    { accountAddress: "0xC1", childContractScope: 0 },
                    { accountAddress: "0xC2", childContractScope: 0 },
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload("", true);

            // Assert - should have empty multicall since no changes needed
            assert.strictEqual(result.updates, undefined);
            assert.strictEqual(result.wrappedUpdates, undefined);
        });
    });

    describe("Account addition scenarios", () => {
        test("should generate addAccounts updates when new accounts are added to existing chains", async () => {
            // Arrange - Add new accounts to existing chains
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 0 }, // existing
                    { accountAddress: "0xA2", childContractScope: 2 }, // existing
                    { accountAddress: "0xA3", childContractScope: 0 }, // new
                ],
                GNOSIS: [
                    { accountAddress: "0xB1", childContractScope: 0 }, // existing
                    { accountAddress: "0xB2", childContractScope: 2 }, // new factory
                ],
                ARBITRUM: [
                    { accountAddress: "0xC1", childContractScope: 0 }, // existing
                    { accountAddress: "0xC2", childContractScope: 0 }, // existing
                ],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
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
                { accountAddress: "0xA3", childContractScope: 0 },
            ]);
            const gnosisUpdate = addAccountsUpdates.find(
                (u) => u.args[0] === "eip155:100",
            );
            assert.ok(gnosisUpdate);
            assert.deepStrictEqual(gnosisUpdate.args[1], [
                { accountAddress: "0xB2", childContractScope: 2 },
            ]);
        });
    });
    describe("Account removal scenarios", () => {
        test("should generate removeAccounts updates when accounts are removed", async () => {
            const csvData = {
                ETHEREUM: [{ accountAddress: "0xA1", childContractScope: 0 }],
                GNOSIS: [],
                ARBITRUM: [{ accountAddress: "0xC1", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
            assert.strictEqual(result.updates.length, 3);
            const removeAccountsUpdates = result.updates.filter(
                (u) => u.function === "removeAccounts",
            );
            assert.strictEqual(removeAccountsUpdates.length, 3);
            const ethereumUpdate = removeAccountsUpdates.find(
                (u) => u.args[0] === "eip155:1",
            );
            assert.ok(ethereumUpdate);
            assert.deepStrictEqual(ethereumUpdate.args[1], ["0xA2"]);
            const gnosisUpdate = removeAccountsUpdates.find(
                (u) => u.args[0] === "eip155:100",
            );
            assert.ok(gnosisUpdate);
            assert.deepStrictEqual(gnosisUpdate.args[1], ["0xB1"]);
            const arbitrumUpdate = removeAccountsUpdates.find(
                (u) => u.args[0] === "eip155:42161",
            );
            assert.ok(arbitrumUpdate);
            assert.deepStrictEqual(arbitrumUpdate.args[1], ["0xC2"]);
        });
    });
    describe("Chain addition scenarios", () => {
        test("should generate addChains updates when new chains are introduced", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
                GNOSIS: [{ accountAddress: "0xB1", childContractScope: 0 }],
                ARBITRUM: [
                    { accountAddress: "0xC1", childContractScope: 0 },
                    { accountAddress: "0xC2", childContractScope: 0 },
                ],
                OPTIMISM: [
                    { accountAddress: "0xD1", childContractScope: 0 },
                    { accountAddress: "0xD2", childContractScope: 2 },
                ],
                POLYGON: [{ accountAddress: "0xE1", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
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
            assert.strictEqual(
                optimismChain.assetRecoveryAddress,
                "0xOPTIMISM_RECOVERY_ADDRESS",
            );
            assert.strictEqual(optimismChain.accounts.length, 2);
            assert.deepStrictEqual(optimismChain.accounts, [
                { accountAddress: "0xD1", childContractScope: 0 },
                { accountAddress: "0xD2", childContractScope: 2 },
            ]);
            const polygonChain = newChains.find(
                (c) => c.caip2ChainId === "eip155:137",
            );
            assert.ok(polygonChain);
            assert.strictEqual(
                polygonChain.assetRecoveryAddress,
                "0xPOLYGON_RECOVERY_ADDRESS",
            );
            assert.strictEqual(polygonChain.accounts.length, 1);
            assert.deepStrictEqual(polygonChain.accounts, [
                { accountAddress: "0xE1", childContractScope: 0 },
            ]);
        });
        test("should generate addChains with empty accounts for new empty chains", async () => {
            const csvData = {
                ETHEREUM: INITIAL_ONCHAIN_STATE.ETHEREUM.accounts,
                GNOSIS: INITIAL_ONCHAIN_STATE.GNOSIS.accounts,
                ARBITRUM: INITIAL_ONCHAIN_STATE.ARBITRUM.accounts,
                OPTIMISM: [],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
            assert.strictEqual(result.updates.length, 1);
            const addChainsUpdates = result.updates.filter(
                (u) => u.function === "addChains",
            );
            assert.strictEqual(addChainsUpdates.length, 1);
            const newChains = addChainsUpdates[0].args[0];
            assert.strictEqual(newChains.length, 1);
            assert.strictEqual(newChains[0].caip2ChainId, "eip155:10");
            assert.strictEqual(newChains[0].accounts.length, 0);
        });
    });
    describe("Chain removal scenarios", () => {
        test("should generate removeChains updates when chains are removed", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.function === "removeChains",
            );
            assert.strictEqual(removeChainsUpdates.length, 1);
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 2);
            assert.ok(chainIdsToRemove.includes("eip155:100"));
            assert.ok(chainIdsToRemove.includes("eip155:42161"));
        });
    });
    describe("Complex mixed scenarios", () => {
        test("should handle simultaneous chain additions, removals, and account changes", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA3", childContractScope: 0 },
                ],
                ARBITRUM: [
                    { accountAddress: "0xC1", childContractScope: 0 },
                    { accountAddress: "0xC2", childContractScope: 0 },
                    { accountAddress: "0xC3", childContractScope: 2 },
                ],
                OPTIMISM: [{ accountAddress: "0xD1", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
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
            assert.ok(removeChainUpdate);
            assert.ok(removeChainUpdate.args[0].includes("eip155:100"));
            const addChainUpdate = result.updates.find(
                (u) => u.function === "addChains",
            );
            assert.ok(addChainUpdate);
            const newChain = addChainUpdate.args[0].find(
                (c) => c.caip2ChainId === "eip155:10",
            );
            assert.ok(newChain);
            const removeAccountUpdate = result.updates.find(
                (u) =>
                    u.function === "removeAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(removeAccountUpdate);
            assert.ok(removeAccountUpdate.args[1].includes("0xA2"));
            const addAccountUpdate = result.updates.find(
                (u) => u.function === "addAccounts" && u.args[0] === "eip155:1",
            );
            assert.ok(addAccountUpdate);
            assert.deepStrictEqual(addAccountUpdate.args[1], [
                { accountAddress: "0xA3", childContractScope: 0 },
            ]);
            const addAccountUpdate2 = result.updates.find(
                (u) =>
                    u.function === "addAccounts" &&
                    u.args[0] === "eip155:42161",
            );
            assert.ok(addAccountUpdate2);
            assert.deepStrictEqual(addAccountUpdate2.args[1], [
                { accountAddress: "0xC3", childContractScope: 2 },
            ]);
        });
        test("should preserve childContractScope values correctly in complex scenarios", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xFactory1", childContractScope: 2 },
                    { accountAddress: "0xNormal1", childContractScope: 0 },
                ],
                OPTIMISM: [
                    { accountAddress: "0xFactory2", childContractScope: 2 },
                    { accountAddress: "0xNormal2", childContractScope: 0 },
                    { accountAddress: "0xNormal3", childContractScope: 0 },
                ],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
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
                (a) => a.accountAddress === "0xFactory2",
            );
            const normalAccounts = optimismChain.accounts.filter((a) =>
                a.accountAddress.includes("Normal"),
            );
            assert.strictEqual(factoryAccount.childContractScope, 2);
            assert.ok(normalAccounts.every((a) => a.childContractScope === 0));
        });
    });
    describe("Edge cases", () => {
        test("should handle completely empty onchain state", async () => {
            const csvData = {
                ETHEREUM: [{ accountAddress: "0xA1", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue({});
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
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
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue({});
            const result = await generatePayload("", true);
            assert.ok(result.wrappedUpdates.calldata);
            assert.strictEqual(result.wrappedUpdates.target, MULTICALL_ADDRESS);
            assert.strictEqual(result.updates.length, 1);
            const removeChainsUpdates = result.updates.filter(
                (u) => u.function === "removeChains",
            );
            assert.strictEqual(removeChainsUpdates.length, 1);
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 3);
            assert.ok(chainIdsToRemove.includes("eip155:1"));
            assert.ok(chainIdsToRemove.includes("eip155:100"));
            assert.ok(chainIdsToRemove.includes("eip155:42161"));
        });
    });

    describe("Chain Property Validation", () => {
        test("should log a warning when asset recovery addresses mismatch", async () => {
            // Arrange
            const consoleWarnSpy = vi.spyOn(console, "warn");

            // Create a specific on-chain state for this test with a mismatch
            const onChainStateWithMismatch = {
                ETHEREUM: {
                    accounts: [
                        { accountAddress: "0xA1", childContractScope: 0 },
                    ],
                    assetRecoveryAddress: "0xDIFFERENT_ONCHAIN_ADDRESS", // Mismatch
                },
                GNOSIS: {
                    accounts: [
                        { accountAddress: "0xB1", childContractScope: 0 },
                    ],
                    assetRecoveryAddress: "0xGNOSIS_RECOVERY_ADDRESS", // Match
                },
            };

            // CSV account data can match to isolate the validation logic
            const csvData = {
                ETHEREUM: [{ accountAddress: "0xA1", childContractScope: 0 }],
                GNOSIS: [{ accountAddress: "0xB1", childContractScope: 0 }],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(
                onChainStateWithMismatch,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);

            // Act
            await generatePayload("", false); // No need to return updates

            // Assert
            const wasCalledWithMismatchWarning = consoleWarnSpy.mock.calls.some(
                (call) =>
                    call[0].includes("Asset Recovery Address mismatch") &&
                    call[0].includes("ETHEREUM") &&
                    call[0].includes("On-chain: 0xDIFFERENT_ONCHAIN_ADDRESS") &&
                    call[0].includes("CSV:      0xETHEREUM_RECOVERY_ADDRESS"),
            );

            assert.ok(
                wasCalledWithMismatchWarning,
                "console.warn was not called with the expected mismatch message for ETHEREUM",
            );

            const wasCalledForGnosis = consoleWarnSpy.mock.calls.some((call) =>
                call[0].includes("GNOSIS"),
            );

            assert.ok(
                !wasCalledForGnosis,
                "console.warn should not be called for GNOSIS as addresses match",
            );

            // Clean up
            consoleWarnSpy.mockRestore();
        });
    });
});
