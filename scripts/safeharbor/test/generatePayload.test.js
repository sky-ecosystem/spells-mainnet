import { test, describe, vi, beforeEach } from "vitest";
import assert from "node:assert";
import {
    arraysEqual,
    findArrayDifferences,
    calculateAccountDifferences,
    generateChainUpdates,
    generateAccountUpdates,
} from "../src/generatePayload.js";

vi.mock("../src/utils/chainUtils.js", () => ({
    getChainId: vi.fn((chainName) => {
        const chainIds = {
            ethereum: 1,
            gnosis: 100,
            arbitrum: 42161,
            optimism: 10,
        };
        return chainIds[chainName] || 1;
    }),
    getChainName: vi.fn((chainId) => {
        const chainNames = {
            1: "ethereum",
            100: "gnosis",
            42161: "arbitrum",
            10: "optimism",
        };
        return chainNames[chainId] || "ethereum";
    }),
    getAssetRecoveryAddress: vi.fn(
        (chainName) => `0x${chainName.toUpperCase()}_RECOVERY_ADDRESS`,
    ),
}));

describe("generatePayload.js", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    describe("arraysEqual", () => {
        test("should return true for two identical arrays", () => {
            assert.strictEqual(arraysEqual([1, 2, 3], [1, 2, 3]), true);
        });

        test("should return false for arrays with different lengths", () => {
            assert.strictEqual(arraysEqual([1, 2], [1, 2, 3]), false);
        });

        test("should return false for arrays with different elements", () => {
            assert.strictEqual(arraysEqual([1, 2, 3], [1, 2, 4]), false);
        });

        test("should return true for two empty arrays", () => {
            assert.strictEqual(arraysEqual([], []), true);
        });
    });

    describe("findArrayDifferences", () => {
        test("should find elements to add and remove correctly", () => {
            const current = ["a", "b", "c"];
            const desired = ["b", "c", "d"];
            const result = findArrayDifferences(current, desired);
            assert.deepStrictEqual(result.toAdd, ["d"]);
            assert.deepStrictEqual(result.toRemove, ["a"]);
        });

        test("should return empty arrays if no differences", () => {
            const current = ["a", "b", "c"];
            const desired = ["a", "b", "c"];
            const result = findArrayDifferences(current, desired);
            assert.deepStrictEqual(result.toAdd, []);
            assert.deepStrictEqual(result.toRemove, []);
        });

        test("should handle all additions", () => {
            const current = [];
            const desired = ["a", "b"];
            const result = findArrayDifferences(current, desired);
            assert.deepStrictEqual(result.toAdd, ["a", "b"]);
            assert.deepStrictEqual(result.toRemove, []);
        });

        test("should handle all removals", () => {
            const current = ["a", "b"];
            const desired = [];
            const result = findArrayDifferences(current, desired);
            assert.deepStrictEqual(result.toAdd, []);
            assert.deepStrictEqual(result.toRemove, ["a", "b"]);
        });

        test("should handle empty arrays for both", () => {
            const current = [];
            const desired = [];
            const result = findArrayDifferences(current, desired);
            assert.deepStrictEqual(result.toAdd, []);
            assert.deepStrictEqual(result.toRemove, []);
        });
    });

    describe("calculateAccountDifferences", () => {
        test("should correctly identify accounts to add and remove", () => {
            const currentAccounts = [
                { accountAddress: "0xA", childContractScope: 0 },
                { accountAddress: "0xB", childContractScope: 0 },
            ];
            const desiredAccounts = [
                { accountAddress: "0xB", isFactory: false },
                { accountAddress: "0xC", isFactory: true }, // Added
            ];

            const result = calculateAccountDifferences(
                currentAccounts,
                desiredAccounts,
            );
            assert.deepStrictEqual(result.toAdd, [
                { accountAddress: "0xC", childContractScope: 3 },
            ]);
            assert.deepStrictEqual(result.toRemove, ["0xA"]);
        });

        test("should return empty arrays if no differences", () => {
            const currentAccounts = [
                { accountAddress: "0xA", childContractScope: 0 },
            ];
            const desiredAccounts = [
                { accountAddress: "0xA", isFactory: false },
            ];
            const result = calculateAccountDifferences(
                currentAccounts,
                desiredAccounts,
            );
            assert.deepStrictEqual(result.toAdd, []);
            assert.deepStrictEqual(result.toRemove, []);
        });

        test("should handle only additions", () => {
            const currentAccounts = [];
            const desiredAccounts = [
                { accountAddress: "0xD", isFactory: false },
            ];
            const result = calculateAccountDifferences(
                currentAccounts,
                desiredAccounts,
            );
            assert.deepStrictEqual(result.toAdd, [
                { accountAddress: "0xD", childContractScope: 0 },
            ]);
            assert.deepStrictEqual(result.toRemove, []);
        });

        test("should handle only removals", () => {
            const currentAccounts = [
                { accountAddress: "0xE", childContractScope: 0 },
            ];
            const desiredAccounts = [];
            const result = calculateAccountDifferences(
                currentAccounts,
                desiredAccounts,
            );
            assert.deepStrictEqual(result.toAdd, []);
            assert.deepStrictEqual(result.toRemove, ["0xE"]);
        });
    });

    describe("generateChainUpdates", () => {
        test("should generate removeChain updates for chains not in desired state", () => {
            const currentChains = [
                { id: 1, accounts: [] },
                { id: 100, accounts: [] },
                { id: 42161, accounts: [] },
            ];
            const chainGroups = {
                ethereum: [],
                gnosis: [],
                // arbitrum is missing, so it should be removed
            };

            // We need to mock the imports for this test to work
            // In a real scenario, you'd use a proper mocking framework
            const updates = generateChainUpdates(currentChains, chainGroups);

            // Should have one removeChain update for arbitrum (42161)
            const removeUpdates = updates.filter(
                (u) => u.function === "removeChain",
            );
            assert.strictEqual(removeUpdates.length, 1);
            assert.strictEqual(removeUpdates[0].args[0], "42161");
        });

        test("should generate addChains updates for new chains", () => {
            const currentChains = [{ id: 1, accounts: [] }];
            const chainGroups = {
                ethereum: [],
                gnosis: [{ accountAddress: "0xABC", childContractScope: 0 }],
            };

            const updates = generateChainUpdates(currentChains, chainGroups);

            // Should have one addChains update for polygon
            const addUpdates = updates.filter(
                (u) => u.function === "addChains",
            );
            assert.strictEqual(addUpdates.length, 1);

            const newChain = addUpdates[0].args[0][0];
            assert.strictEqual(newChain.id, 100);

            assert.strictEqual(newChain.accounts.length, 1);
            assert.strictEqual(newChain.accounts[0].accountAddress, "0xABC");
        });

        test("should handle no changes needed", () => {
            const currentChains = [
                { id: 1, accounts: [] },
                { id: 100, accounts: [] },
            ];
            const chainGroups = {
                ethereum: [],
                gnosis: [],
            };

            const updates = generateChainUpdates(currentChains, chainGroups);
            assert.strictEqual(updates.length, 0);
        });

        test("should handle both additions and removals", () => {
            const currentChains = [
                { id: 1, accounts: [] },
                { id: 42161, accounts: [] },
            ];
            const chainGroups = {
                ethereum: [],
                gnosis: [],
            };

            const updates = generateChainUpdates(currentChains, chainGroups);

            assert.strictEqual(updates.length, 2);

            const removeUpdates = updates.filter(
                (u) => u.function === "removeChain",
            );
            const addUpdates = updates.filter(
                (u) => u.function === "addChains",
            );

            assert.strictEqual(removeUpdates.length, 1);
            assert.strictEqual(addUpdates.length, 1);
        });

        test("should include correct calldata and raw-abi for removeChain", () => {
            const currentChains = [{ id: 1, accounts: [] }];
            const chainGroups = {};

            const updates = generateChainUpdates(currentChains, chainGroups);

            assert.strictEqual(updates[0].function, "removeChain");
            assert.strictEqual(updates[0].args[0], "1");
            assert.ok(updates[0].calldata);
            assert.ok(updates[0]["raw-abi"]);
        });

        test("should include correct calldata and raw-abi for addChains", () => {
            const currentChains = [];
            const chainGroups = {
                ethereum: [{ accountAddress: "0xTEST", childContractScope: 0 }],
            };

            const updates = generateChainUpdates(currentChains, chainGroups);

            assert.strictEqual(updates[0].function, "addChains");
            assert.strictEqual(updates[0].args[0].length, 1);
            assert.ok(updates[0].calldata);
            assert.ok(updates[0]["raw-abi"]);
        });
    });

    describe("generateAccountUpdates", () => {
        test("should generate setAccounts updates for account replacements", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xOLD1", childContractScope: 0 },
                        { accountAddress: "0xOLD2", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [
                    { accountAddress: "0xNEW1", childContractScope: 0 },
                    { accountAddress: "0xNEW2", childContractScope: 0 },
                ],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have one setAccounts update replacing both accounts
            const setAccountsUpdates = updates.filter(
                (u) => u.function === "setAccounts",
            );
            assert.strictEqual(setAccountsUpdates.length, 1);

            const update = setAccountsUpdates[0];

            assert.strictEqual(update.args[0], 0); // chainId index
            assert.deepStrictEqual(update.args[1], [0, 1]); // account indices
            assert.strictEqual(update.args[2].length, 2); // new accounts
            assert.strictEqual(update.args[2][0].accountAddress, "0xNEW1");
            assert.strictEqual(update.args[2][1].accountAddress, "0xNEW2");
        });

        test("should generate removeAccount updates for excess removals", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                        { accountAddress: "0xB", childContractScope: 0 },
                        { accountAddress: "0xC", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [{ accountAddress: "0xNEW", childContractScope: 0 }],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have one setAccounts (replacing one) and two removeAccount updates
            const setAccountsUpdates = updates.filter(
                (u) => u.function === "setAccounts",
            );
            const removeAccountUpdates = updates.filter(
                (u) => u.function === "removeAccount",
            );

            assert.strictEqual(setAccountsUpdates.length, 1);
            assert.strictEqual(removeAccountUpdates.length, 2);

            // removeAccount should be called with decreasing indices (to avoid index shifting issues)
            assert.strictEqual(removeAccountUpdates[0].args[1], 2); // Remove index 2 first
            assert.strictEqual(removeAccountUpdates[1].args[1], 1); // Then remove index 1
        });

        test("should generate addAccounts updates for excess additions", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [
                    { accountAddress: "0xNEW1", childContractScope: 0 },
                    { accountAddress: "0xNEW2", childContractScope: 0 },
                    { accountAddress: "0xNEW3", childContractScope: 0 },
                ],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have one setAccounts (replacing one) and one addAccounts (adding two)
            const setAccountsUpdates = updates.filter(
                (u) => u.function === "setAccounts",
            );
            const addAccountsUpdates = updates.filter(
                (u) => u.function === "addAccounts",
            );

            assert.strictEqual(setAccountsUpdates.length, 1);
            assert.strictEqual(addAccountsUpdates.length, 1);

            // addAccounts should contain the remaining 2 accounts
            assert.strictEqual(addAccountsUpdates[0].args[1].length, 2);
        });

        test("should handle no account changes", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [{ accountAddress: "0xA", childContractScope: 0 }],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);
            assert.strictEqual(updates.length, 0);
        });

        test("should handle chains with no desired accounts", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                        { accountAddress: "0xB", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [], // No desired accounts
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have two removeAccount updates
            const removeAccountUpdates = updates.filter(
                (u) => u.function === "removeAccount",
            );
            assert.strictEqual(removeAccountUpdates.length, 2);
        });

        test("should handle chains not in chainGroups", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                // ethereum not included
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should remove the existing account since no desired accounts
            const removeAccountUpdates = updates.filter(
                (u) => u.function === "removeAccount",
            );
            assert.strictEqual(removeAccountUpdates.length, 1);
        });

        test("should preserve childContractScope when adding accounts", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [],
                },
            ];
            const chainGroups = {
                ethereum: [
                    {
                        accountAddress: "0xFactory",
                        childContractScope: 3,
                        isFactory: true,
                    },
                    {
                        accountAddress: "0xNormal",
                        childContractScope: 0,
                        isFactory: false,
                    },
                ],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            const addAccountsUpdates = updates.filter(
                (u) => u.function === "addAccounts",
            );
            assert.strictEqual(addAccountsUpdates.length, 1);

            const accounts = addAccountsUpdates[0].args[1];
            const factoryAccount = accounts.find(
                (acc) => acc.accountAddress === "0xFactory",
            );
            const normalAccount = accounts.find(
                (acc) => acc.accountAddress === "0xNormal",
            );

            assert.strictEqual(factoryAccount.childContractScope, 3);
            assert.strictEqual(normalAccount.childContractScope, 0);
        });

        test("should include correct calldata and raw-abi for all operations", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [{ accountAddress: "0xB", childContractScope: 0 }],
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have one setAccounts update
            assert.strictEqual(updates.length, 1);

            const update = updates[0];
            assert.strictEqual(update.function, "setAccounts");
            assert.ok(update.calldata);
            assert.ok(update["raw-abi"]);
        });

        test("should handle multiple chains with different account changes", () => {
            const currentChains = [
                {
                    id: 1,
                    accounts: [
                        { accountAddress: "0xA", childContractScope: 0 },
                    ],
                },
                {
                    id: 137,
                    accounts: [
                        { accountAddress: "0xB", childContractScope: 0 },
                    ],
                },
            ];
            const chainGroups = {
                ethereum: [
                    { accountAddress: "0xNEW_A", childContractScope: 0 },
                ],
                polygon: [], // Remove all accounts from polygon
            };

            const updates = generateAccountUpdates(currentChains, chainGroups);

            // Should have updates for both chains
            assert.ok(updates.length >= 2);

            // Check that updates reference correct chain indices
            const ethereumUpdates = updates.filter((u) => u.args[0] === 0);
            const polygonUpdates = updates.filter((u) => u.args[0] === 1);

            assert.ok(ethereumUpdates.length > 0);
            assert.ok(polygonUpdates.length > 0);
        });
    });

    describe("Integration tests", () => {
        test("calculateAccountDifferences should work with generateAccountUpdates", () => {
            const currentAccounts = [
                { accountAddress: "0xA", childContractScope: 0 },
                { accountAddress: "0xB", childContractScope: 0 },
            ];
            const desiredAccounts = [
                { accountAddress: "0xB", isFactory: false },
                { accountAddress: "0xC", isFactory: true },
            ];

            const diff = calculateAccountDifferences(
                currentAccounts,
                desiredAccounts,
            );

            // Verify the structure matches what generateAccountUpdates expects
            assert.ok(Array.isArray(diff.toAdd));
            assert.ok(Array.isArray(diff.toRemove));
            assert.ok(
                diff.toAdd.every(
                    (acc) =>
                        acc.accountAddress &&
                        typeof acc.childContractScope === "number",
                ),
            );
            assert.ok(diff.toRemove.every((addr) => typeof addr === "string"));
        });
    });
});
