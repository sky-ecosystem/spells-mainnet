import { test, expect, it, describe, vi, beforeEach } from "vitest";
import assert from "node:assert";
import { generatePayload } from "../src/generatePayload.js";

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
            const result = await generatePayload("");

            // Assert - should have empty result since no changes needed
            assert.strictEqual(result.updates.length, 0);
            assert.strictEqual(result.solidityCode, "");
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
            expect(result.solidityCode).toMatchSnapshot();
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
                ARBITRUM: [{ accountAddress: "0xC2", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue(
                INITIAL_ONCHAIN_STATE,
            );
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            assert.deepStrictEqual(arbitrumUpdate.args[1], ["0xC1"]);
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            // Arrange
            const consoleWarnSpy = vi.spyOn(console, "warn");

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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            assert.ok(removeChainUpdate.args[0].includes("eip155:100"));
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
            assert.ok(removeAccountUpdate.args[1].includes("0xA2"));
            const addAccountUpdate = result.updates[addAccountIndex];
            assert.ok(addAccountUpdate.args[1].length, 1);
            assert.deepStrictEqual(addAccountUpdate.args[1], [
                { accountAddress: "0xA3", childContractScope: 0 },
            ]);
            const addAccountUpdate2 = result.updates.find(
                (u) =>
                    u.function === "addAccounts" &&
                    u.args[0] === "eip155:42161",
            );
            assert.ok(addAccountUpdate2.args[1].length, 1);
            assert.deepStrictEqual(addAccountUpdate2.args[1], [
                { accountAddress: "0xC3", childContractScope: 2 },
            ]);

            // Assert no warnings were logged
            const hasWarnings = consoleWarnSpy.mock.calls.some(
                (call) => call[0].includes("‼️") || call[0].includes("⚠️"),
            );
            assert.ok(
                !hasWarnings,
                "Console should not contain warning markers (‼️ or ⚠️)",
            );

            // Clean up
            consoleWarnSpy.mockRestore();
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
        test("should handle completely empty onchain state", async () => {
            const csvData = {
                ETHEREUM: [{ accountAddress: "0xA1", childContractScope: 0 }],
            };
            getNormalizedDataFromOnchainState.mockResolvedValue({});
            getNormalizedContractsInScopeFromCSV.mockResolvedValue(csvData);
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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
        test("shoud handle account scope changes", async () => {
            const csvData = {
                ETHEREUM: [
                    { accountAddress: "0xA1", childContractScope: 2 },
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
            const result = await generatePayload("");
            assert.ok(result.solidityCode);
            assert.ok(result.solidityCode.includes("_updateSafeHarbor"));
            expect(result.solidityCode).toMatchSnapshot();
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

        test("should log a warning when unknown chain details are found in on-chain state", async () => {
            // Arrange
            const consoleWarnSpy = vi.spyOn(console, "warn");

            // Import the actual implementation instead of the mock
            const {
                getNormalizedDataFromOnchainState:
                    actualGetNormalizedDataFromOnchainState,
            } = await vi.importActual("../src/fetchOnchain.js");

            // Mock agreement contract with an unknown chain
            const mockAgreementContract = {
                getDetails: vi.fn().mockResolvedValue({
                    chains: [
                        {
                            caip2ChainId: "eip155:1", // Known chain (ETHEREUM)
                            assetRecoveryAddress: "0xETHEREUM_RECOVERY_ADDRESS",
                            accounts: [["0xA1", 0]],
                        },
                        {
                            caip2ChainId: "eip155:999", // Unknown chain
                            assetRecoveryAddress: "0xUNKNOWN_RECOVERY_ADDRESS",
                            accounts: [["0xU1", 0]],
                        },
                    ],
                }),
            };

            // Act - use the actual implementation
            const result = await actualGetNormalizedDataFromOnchainState(
                mockAgreementContract,
                CHAIN_DETAILS,
            );

            // Assert
            const wasCalledWithUnknownChainWarning =
                consoleWarnSpy.mock.calls.some(
                    (call) =>
                        call[0].includes(
                            "Unknown chain details in on-chain state",
                        ) && call[0].includes("caip2ChainId='eip155:999'"),
                );

            assert.ok(
                wasCalledWithUnknownChainWarning,
                "console.warn should be called with a warning about unknown chain in on-chain state",
            );

            // Verify that the unknown chain was not included in the result
            assert.ok(!result.hasOwnProperty("UNKNOWN"));
            assert.ok(result.hasOwnProperty("ETHEREUM"));

            // Clean up
            consoleWarnSpy.mockRestore();
        });
    });

    describe("Chain Details Duplicate Validation", () => {
        test("should log a warning when duplicate chain names are found in CSV", async () => {
            // Arrange
            const consoleWarnSpy = vi.spyOn(console, "warn");

            // Mock fetch to return CSV data with duplicate chain names
            global.fetch = vi.fn().mockResolvedValue({
                ok: true,
                headers: {
                    get: vi.fn().mockReturnValue("text/csv"),
                },
                text: vi.fn().mockResolvedValue(
                    `Name,Chain Id,Asset Recovery Address
ETHEREUM,eip155:1,0xETHEREUM_RECOVERY_ADDRESS
ETHEREUM,eip155:2,0xANOTHER_ADDRESS
GNOSIS,eip155:100,0xGNOSIS_RECOVERY_ADDRESS`,
                ),
            });

            // Import the actual implementation to test it
            const { getChainDetailsFromCSV: actualGetChainDetailsFromCSV } =
                await vi.importActual("../src/fetchCSV.js");

            // Act
            await actualGetChainDetailsFromCSV("fake-url");

            // Assert
            const wasCalledWithDuplicateNamesWarning =
                consoleWarnSpy.mock.calls.some(
                    (call) =>
                        call[0].includes(
                            "⚠️  Warning: Duplicate chain name found in CSV",
                        ) && call[0].includes("ETHEREUM"),
                );

            assert.ok(
                wasCalledWithDuplicateNamesWarning,
                "console.warn should be called with a warning about duplicate chain name",
            );

            // Clean up
            consoleWarnSpy.mockRestore();
            delete global.fetch;
        });

        test("should log a warning when duplicate chain IDs are found in CSV", async () => {
            // Arrange
            const consoleWarnSpy = vi.spyOn(console, "warn");

            // Mock fetch to return CSV data with duplicate chain IDs
            global.fetch = vi.fn().mockResolvedValue({
                ok: true,
                headers: {
                    get: vi.fn().mockReturnValue("text/csv"),
                },
                text: vi.fn().mockResolvedValue(
                    `Name,Chain Id,Asset Recovery Address
ETHEREUM,eip155:1,0xETHEREUM_RECOVERY_ADDRESS
ETHEREUM_DUPLICATE,eip155:1,0xANOTHER_ADDRESS
GNOSIS,eip155:100,0xGNOSIS_RECOVERY_ADDRESS`,
                ),
            });

            // Import the actual implementation to test it
            const { getChainDetailsFromCSV: actualGetChainDetailsFromCSV } =
                await vi.importActual("../src/fetchCSV.js");

            // Act
            await actualGetChainDetailsFromCSV("fake-url");

            // Assert
            const wasCalledWithDuplicateChainIdsWarning =
                consoleWarnSpy.mock.calls.some(
                    (call) =>
                        call[0].includes(
                            "⚠️  Warning: Duplicate chain ID found in CSV",
                        ) && call[0].includes("eip155:1"),
                );

            assert.ok(
                wasCalledWithDuplicateChainIdsWarning,
                "console.warn should be called with a warning about duplicate chain ID",
            );

            // Clean up
            consoleWarnSpy.mockRestore();
            delete global.fetch;
        });
    });
});
