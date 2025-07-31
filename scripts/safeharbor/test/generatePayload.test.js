import { test, describe, vi, beforeEach } from "vitest";
import assert from "node:assert";
import { generatePayload } from "../src/generatePayload.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "../src/constants.js";

// Mock the dependencies
vi.mock("../src/fetchCSV.js");
vi.mock("../src/fetchOnchain.js");
vi.mock("../src/utils/chainUtils.js");
vi.mock("fs", () => ({
    writeFileSync: vi.fn(),
}));

import { getNormalizedDataFromCSV } from "../src/fetchCSV.js";
import { getNormalizedDataFromOnchainState } from "../src/fetchOnchain.js";

// Mock chain utilities
vi.mock("../src/utils/chainUtils.js", () => ({
    getChainId: vi.fn((chainName) => {
        const chainIds = {
            ethereum: 1,
            gnosis: 100,
            arbitrum: 42161,
            optimism: 10,
            polygon: 137,
        };
        return chainIds[chainName] || 1;
    }),
    getChainName: vi.fn((chainId) => {
        const chainNames = {
            1: "ethereum",
            100: "gnosis",
            42161: "arbitrum", 
            10: "optimism",
            137: "polygon",
        };
        return chainNames[chainId] || "ethereum";
    }),
    getAssetRecoveryAddress: vi.fn(
        (chainName) => `0x${chainName.toUpperCase()}_RECOVERY_ADDRESS`,
    ),
}));


describe("generatePayload E2E Tests", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    // Test Fixtures
    const INITIAL_ONCHAIN_STATE = {
        ethereum: [
            { accountAddress: "0xA1", childContractScope: 0 },
            { accountAddress: "0xA2", childContractScope: 2 },
        ],
        gnosis: [
            { accountAddress: "0xB1", childContractScope: 0 },
        ],
        arbitrum: [
            { accountAddress: "0xC1", childContractScope: 0 },
            { accountAddress: "0xC2", childContractScope: 0 },
        ],
    };

    describe("No changes scenario", () => {
        test("should generate no updates when onchain and CSV data match", async () => {
            // Arrange - CSV data matches onchain exactly
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
                gnosis: [
                    { accountAddress: "0xB1", childContractScope: 0 },
                ],
                arbitrum: [
                    { accountAddress: "0xC1", childContractScope: 0 },
                    { accountAddress: "0xC2", childContractScope: 0 },
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert - should have empty multicall since no changes needed
            assert.strictEqual(result.length, 0);
        });
    });

    describe("Account addition scenarios", () => {
        test("should generate addAccounts updates when new accounts are added to existing chains", async () => {
            // Arrange - Add new accounts to existing chains
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 }, // existing
                    { accountAddress: "0xA2", childContractScope: 2 }, // existing
                    { accountAddress: "0xA3", childContractScope: 0 }, // new
                ],
                gnosis: [
                    { accountAddress: "0xB1", childContractScope: 0 }, // existing
                    { accountAddress: "0xB2", childContractScope: 2 }, // new factory
                ],
                arbitrum: [
                    { accountAddress: "0xC1", childContractScope: 0 }, // existing
                    { accountAddress: "0xC2", childContractScope: 0 }, // existing
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert
            assert.strictEqual(result.length, 3); // 2 additions and 1 multicall

            const addAccountsUpdates = result.filter(u => u.function === "addAccounts");
            assert.strictEqual(addAccountsUpdates.length, 2); // ethereum and gnosis

            // Check ethereum addition
            const ethereumUpdate = addAccountsUpdates.find(u => u.args[0] === 1);
            assert.ok(ethereumUpdate);
            assert.deepStrictEqual(ethereumUpdate.args[1], [
                { accountAddress: "0xA3", childContractScope: 0 }
            ]);

            // Check gnosis addition
            const gnosisUpdate = addAccountsUpdates.find(u => u.args[0] === 100);
            assert.ok(gnosisUpdate);
            assert.deepStrictEqual(gnosisUpdate.args[1], [
                { accountAddress: "0xB2", childContractScope: 2 }
            ]);

            // Check multicall
            const multicallUpdate = result.find(u => u.function === "multicall");
            assert.ok(multicallUpdate);
            assert.strictEqual(multicallUpdate.args[0].length, 2);
            assert.strictEqual(multicallUpdate.args[0][0].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][0].callData, ethereumUpdate.calldata);
            assert.strictEqual(multicallUpdate.args[0][1].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][1].callData, gnosisUpdate.calldata);
        });
    });

    describe("Account removal scenarios", () => {
        test("should generate removeAccounts updates when accounts are removed", async () => {
            // Arrange - Remove some accounts
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 }, // keep
                    // 0xA2 removed
                ],
                gnosis: [
                    // 0xB1 removed - entire chain becomes empty but still exists
                ],
                arbitrum: [
                    { accountAddress: "0xC1", childContractScope: 0 }, // keep
                    // 0xC2 removed
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert
            assert.strictEqual(result.length, 4);

            const removeAccountsUpdates = result.filter(u => u.function === "removeAccounts");
            assert.strictEqual(removeAccountsUpdates.length, 3); // all three chains have removals

            // Check ethereum removal
            const ethereumUpdate = removeAccountsUpdates.find(u => u.args[0] === 1);
            assert.ok(ethereumUpdate);
            assert.deepStrictEqual(ethereumUpdate.args[1], ["0xA2"]);

            // Check gnosis removal
            const gnosisUpdate = removeAccountsUpdates.find(u => u.args[0] === 100);
            assert.ok(gnosisUpdate);
            assert.deepStrictEqual(gnosisUpdate.args[1], ["0xB1"]);

            // Check arbitrum removal
            const arbitrumUpdate = removeAccountsUpdates.find(u => u.args[0] === 42161);
            assert.ok(arbitrumUpdate);
            assert.deepStrictEqual(arbitrumUpdate.args[1], ["0xC2"]);

            // Check multicall
            const multicallUpdate = result.find(u => u.function === "multicall");
            assert.ok(multicallUpdate);
            assert.strictEqual(multicallUpdate.args[0].length, 3);
            assert.strictEqual(multicallUpdate.args[0][0].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][0].callData, ethereumUpdate.calldata);
            assert.strictEqual(multicallUpdate.args[0][1].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][1].callData, gnosisUpdate.calldata);
            assert.strictEqual(multicallUpdate.args[0][2].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][2].callData, arbitrumUpdate.calldata);
        });
    });

    describe("Chain addition scenarios", () => {
        test("should generate addChains updates when new chains are introduced", async () => {
            // Arrange - Add new chains
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
                gnosis: [
                    { accountAddress: "0xB1", childContractScope: 0 },
                ],
                arbitrum: [
                    { accountAddress: "0xC1", childContractScope: 0 },
                    { accountAddress: "0xC2", childContractScope: 0 },
                ],
                optimism: [ // new chain
                    { accountAddress: "0xD1", childContractScope: 0 },
                    { accountAddress: "0xD2", childContractScope: 2 },
                ],
                polygon: [ // new chain
                    { accountAddress: "0xE1", childContractScope: 0 },
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert
            assert.strictEqual(result.length, 2);

            const addChainsUpdates = result.filter(u => u.function === "addChains");
            assert.strictEqual(addChainsUpdates.length, 1); // Should batch new chains together

            const newChains = addChainsUpdates[0].args[0];
            assert.strictEqual(newChains.length, 2); // optimism and polygon

            // Check optimism chain
            const optimismChain = newChains.find(c => c.caip2ChainId === 10);
            assert.ok(optimismChain);
            assert.strictEqual(optimismChain.assetRecoveryAddress, "0xOPTIMISM_RECOVERY_ADDRESS");
            assert.strictEqual(optimismChain.accounts.length, 2);
            assert.deepStrictEqual(optimismChain.accounts, [
                { accountAddress: "0xD1", childContractScope: 0 },
                { accountAddress: "0xD2", childContractScope: 2 },
            ]);

            // Check polygon chain
            const polygonChain = newChains.find(c => c.caip2ChainId === 137);
            assert.ok(polygonChain);
            assert.strictEqual(polygonChain.assetRecoveryAddress, "0xPOLYGON_RECOVERY_ADDRESS");
            assert.strictEqual(polygonChain.accounts.length, 1);
            assert.deepStrictEqual(polygonChain.accounts, [
                { accountAddress: "0xE1", childContractScope: 0 },
            ]);

            // Check multicall
            const multicallUpdate = result.find(u => u.function === "multicall");

            assert.ok(multicallUpdate);
            assert.strictEqual(multicallUpdate.args[0].length, 1);
            assert.strictEqual(multicallUpdate.args[0][0].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][0].callData, addChainsUpdates[0].calldata);
        });

        test("should generate addChains with empty accounts for new empty chains", async () => {
            // Arrange - Add new empty chain
            const csvData = {
                ...INITIAL_ONCHAIN_STATE,
                optimism: [], // new empty chain
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert
            assert.strictEqual(result.length, 2);

            const addChainsUpdates = result.filter(u => u.function === "addChains");
            assert.strictEqual(addChainsUpdates.length, 1);

            const newChains = addChainsUpdates[0].args[0];
            assert.strictEqual(newChains.length, 1);
            assert.strictEqual(newChains[0].caip2ChainId, 10);
            assert.strictEqual(newChains[0].accounts.length, 0);

            // Check multicall
            const multicallUpdate = result.find(u => u.function === "multicall");
            assert.ok(multicallUpdate);
            assert.strictEqual(multicallUpdate.args[0].length, 1);
            assert.strictEqual(multicallUpdate.args[0][0].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate.args[0][0].callData, addChainsUpdates[0].calldata);
        });
    });

    describe("Chain removal scenarios", () => {
        test("should generate removeChains updates when chains are removed", async () => {
            // Arrange - Remove some chains
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                    { accountAddress: "0xA2", childContractScope: 2 },
                ],
                // gnosis and arbitrum removed
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert
            assert.strictEqual(result.length, 2);

            const removeChainsUpdates = result.filter(u => u.function === "removeChains");
            assert.strictEqual(removeChainsUpdates.length, 1); // Should batch removals

            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 2);
            assert.ok(chainIdsToRemove.includes(100)); // gnosis
            assert.ok(chainIdsToRemove.includes(42161)); // arbitrum
        });
    });

    describe("Complex mixed scenarios", () => {
        test("should handle simultaneous chain additions, removals, and account changes", async () => {
            // Arrange - Complex scenario
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 }, // existing
                    { accountAddress: "0xA3", childContractScope: 0 }, // new (0xA2 removed)
                ],
                // gnosis removed entirely
                arbitrum: [
                    { accountAddress: "0xC1", childContractScope: 0 }, // existing
                    { accountAddress: "0xC2", childContractScope: 0 }, // existing
                    { accountAddress: "0xC3", childContractScope: 2 }, // new
                ],
                optimism: [ // new chain
                    { accountAddress: "0xD1", childContractScope: 0 },
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert - check that we have all expected update types
            // Included updates:
            // 1. RemoveChains: Gnosis
            // 2. AddChains: Optimism, Polygon
            // 3. RemoveAccounts: Ethereum 0xA2
            // 4. AddAccounts: Ethereum 0xA3
            // 5. AddAccounts: Arbitrum 0xC3
            // 6. Multicall
            assert.strictEqual(result.length, 6);

            const chainUpdates = result.filter(u => u.function === "removeChains" || u.function === "addChains");
            const accountUpdates = result.filter(u => u.function === "removeAccounts" || u.function === "addAccounts");
            const multicallUpdate = result.filter(u => u.function === "multicall");

            assert.ok(chainUpdates.length > 0, "Should have chain updates");
            assert.ok(accountUpdates.length > 0, "Should have account updates");
            assert.strictEqual(multicallUpdate.length, 1, "Should have exactly one multicall wrapper");

            // Verify chain removal
            const removeChainUpdate = result.find(u => u.function === "removeChains");
            assert.ok(removeChainUpdate);
            assert.ok(removeChainUpdate.args[0].includes(100)); // gnosis removed

            // Verify chain addition
            const addChainUpdate = result.find(u => u.function === "addChains");
            assert.ok(addChainUpdate);
            const newChain = addChainUpdate.args[0].find(c => c.caip2ChainId === 10);
            assert.ok(newChain); // optimism added

            // Verify account changes
            const removeAccountUpdate = result.find(u => u.function === "removeAccounts" && u.args[0] === 1);
            assert.ok(removeAccountUpdate);
            assert.ok(removeAccountUpdate.args[1].includes("0xA2")); // ethereum account removed

            const addAccountUpdate = result.find(u => u.function === "addAccounts" && u.args[0] === 1);
            assert.ok(addAccountUpdate);
            assert.deepStrictEqual(addAccountUpdate.args[1], [
                { accountAddress: "0xA3", childContractScope: 0 }
            ]);

            const addAccountUpdate2 = result.find(u => u.function === "addAccounts" && u.args[0] === 42161);
            assert.ok(addAccountUpdate2);
            assert.deepStrictEqual(addAccountUpdate2.args[1], [
                { accountAddress: "0xC3", childContractScope: 2 }
            ]);

            // Verify multicall
            assert.strictEqual(multicallUpdate[0].args[0].length, 5);
            assert.strictEqual(multicallUpdate[0].args[0][0].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate[0].args[0][0].callData, removeChainUpdate.calldata);
            assert.strictEqual(multicallUpdate[0].args[0][1].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate[0].args[0][1].callData, addChainUpdate.calldata);
            assert.strictEqual(multicallUpdate[0].args[0][2].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate[0].args[0][2].callData, removeAccountUpdate.calldata);
            assert.strictEqual(multicallUpdate[0].args[0][3].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate[0].args[0][3].callData, addAccountUpdate.calldata);
            assert.strictEqual(multicallUpdate[0].args[0][4].target, AGREEMENT_ADDRESS);
            assert.strictEqual(multicallUpdate[0].args[0][4].callData, addAccountUpdate2.calldata);
        });

        test("should preserve childContractScope values correctly in complex scenarios", async () => {
            // Arrange - Focus on childContractScope handling
            const csvData = {
                ethereum: [
                    { accountAddress: "0xFactory1", childContractScope: 2 }, // factory
                    { accountAddress: "0xNormal1", childContractScope: 0 }, // regular
                ],
                optimism: [ // new chain with mixed account types
                    { accountAddress: "0xFactory2", childContractScope: 2 }, // factory
                    { accountAddress: "0xNormal2", childContractScope: 0 }, // regular
                    { accountAddress: "0xNormal3", childContractScope: 0 }, // regular
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert - verify childContractScope preservation in all operations
            const addChainUpdate = result.find(u => u.function === "addChains");
            assert.ok(addChainUpdate);
            
            const optimismChain = addChainUpdate.args[0].find(c => c.caip2ChainId === 10);
            assert.ok(optimismChain);
            
            const factoryAccount = optimismChain.accounts.find(a => a.accountAddress === "0xFactory2");
            const normalAccounts = optimismChain.accounts.filter(a => a.accountAddress.includes("Normal"));
            
            assert.strictEqual(factoryAccount.childContractScope, 2);
            assert.ok(normalAccounts.every(a => a.childContractScope === 0));
        });
    });

    describe("Edge cases", () => {
        test("should handle completely empty onchain state", async () => {
            // Arrange
            const csvData = {
                ethereum: [
                    { accountAddress: "0xA1", childContractScope: 0 },
                ],
            };

            getNormalizedDataFromOnchainState.mockResolvedValue({});
            getNormalizedDataFromCSV.mockResolvedValue(csvData);

            // Act
            const result = await generatePayload();

            // Assert - should only have addChains
            const addChainsUpdates = result.filter(u => u.function === "addChains");
            assert.strictEqual(addChainsUpdates.length, 1);
            
            const removeUpdates = result.filter(u => u.function.includes("remove"));
            assert.strictEqual(removeUpdates.length, 0);
        });

        test("should handle completely empty CSV state", async () => {
            // Arrange
            getNormalizedDataFromOnchainState.mockResolvedValue(INITIAL_ONCHAIN_STATE);
            getNormalizedDataFromCSV.mockResolvedValue({});

            // Act
            const result = await generatePayload();

            // Assert - should only have removeChains (batched)
            const removeChainsUpdates = result.filter(u => u.function === "removeChains");
            assert.strictEqual(removeChainsUpdates.length, 1);
            
            const chainIdsToRemove = removeChainsUpdates[0].args[0];
            assert.strictEqual(chainIdsToRemove.length, 3); // all chains removed
            assert.ok(chainIdsToRemove.includes(1)); // ethereum
            assert.ok(chainIdsToRemove.includes(100)); // gnosis  
            assert.ok(chainIdsToRemove.includes(42161)); // arbitrum
        });

    });
});
