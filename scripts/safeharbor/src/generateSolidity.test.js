import { expect, test } from "vitest";
import { generateSolidityCode } from "./generateSolidity.js";

test("returns an empty snippet when there are no updates", () => {
    expect(generateSolidityCode([])).toBe("");
});

test.each([
    {
        scenario: "chain removals in the supplied order",
        updates: [
            {
                fn: "removeChains",
                args: [["eip155:8453", "eip155:1"]],
                calldata: "0x1234",
            },
        ],
        expected:
            "bytes[] memory calldatas = new bytes[](1);\n\n// Remove chains: eip155:8453, eip155:1\ncalldatas[0] = hex'1234';\n\n_updateSafeHarbor(calldatas);",
    },
    {
        scenario: "chain additions with and without accounts",
        updates: [
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                {
                                    accountAddress:
                                        "0x3000000000000000000000000000000000000002",
                                    childContractScope: 2,
                                },
                                {
                                    accountAddress:
                                        "0x3000000000000000000000000000000000000001",
                                    childContractScope: 0,
                                },
                            ],
                        },
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [],
                        },
                    ],
                ],
                calldata: "abcd",
            },
        ],
        expected:
            "bytes[] memory calldatas = new bytes[](1);\n\n// Add new eip155:8453 with recovery address 0x1000000000000000000000000000000000000002 and accounts: 0x3000000000000000000000000000000000000002, 0x3000000000000000000000000000000000000001; Add new eip155:1 with recovery address 0x1000000000000000000000000000000000000001 and no accounts\ncalldatas[0] = hex'abcd';\n\n_updateSafeHarbor(calldatas);",
    },
    {
        scenario: "account removals in the supplied order",
        updates: [
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    [
                        "0x2000000000000000000000000000000000000002",
                        "0x2000000000000000000000000000000000000001",
                    ],
                ],
                calldata: "0xabcd",
            },
        ],
        expected:
            "bytes[] memory calldatas = new bytes[](1);\n\n// Remove accounts from eip155:1 chain: 0x2000000000000000000000000000000000000002, 0x2000000000000000000000000000000000000001\ncalldatas[0] = hex'abcd';\n\n_updateSafeHarbor(calldatas);",
    },
    {
        scenario: "account additions in the supplied order",
        updates: [
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
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                ],
                calldata: "1234",
            },
        ],
        expected:
            "bytes[] memory calldatas = new bytes[](1);\n\n// Add accounts to eip155:1 chain: 0x2000000000000000000000000000000000000002, 0x2000000000000000000000000000000000000001\ncalldatas[0] = hex'1234';\n\n_updateSafeHarbor(calldatas);",
    },
])("renders $scenario", ({ updates, expected }) => {
    expect(generateSolidityCode(updates)).toBe(expected);
});

test("rejects unknown operations", () => {
    expect(() =>
        generateSolidityCode([
            { fn: "unknownOperation", args: [], calldata: "0x1234" },
        ]),
    ).toThrow("Unknown update");
});

test("trims each Solidity line while preserving internal spacing and blank lines", () => {
    const code = generateSolidityCode([
        {
            fn: "removeChains",
            args: [["eip155:1 \t"]],
            calldata: "0x1234",
        },
        {
            fn: "removeChains",
            args: [["eip155:8453"]],
            calldata: "0xabcd",
        },
    ]);

    expect(code).toBe(
        "bytes[] memory calldatas = new bytes[](2);\n\n// Remove chains: eip155:1\ncalldatas[0] = hex'1234';\n\n// Remove chains: eip155:8453\ncalldatas[1] = hex'abcd';\n\n_updateSafeHarbor(calldatas);",
    );
});
