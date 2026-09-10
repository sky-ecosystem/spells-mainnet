import { expect, test } from "vitest";
import { dedent } from "../utils/dedent.js";
import { generateSolidity } from "./solidity.js";

test("returns an empty snippet when there are no updates", () => {
    expect(generateSolidity([])).toBe("");
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
        expected: dedent`
            bytes[] memory calldatas = new bytes[](1);

            // Remove chains: eip155:8453, eip155:1
            calldatas[0] = hex'1234';

            _updateSafeHarbor(calldatas);
        `,
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
        expected: dedent`
            bytes[] memory calldatas = new bytes[](1);

            // Add new eip155:8453 with recovery address 0x1000000000000000000000000000000000000002 and accounts: 0x3000000000000000000000000000000000000002, 0x3000000000000000000000000000000000000001; Add new eip155:1 with recovery address 0x1000000000000000000000000000000000000001 and no accounts
            calldatas[0] = hex'abcd';

            _updateSafeHarbor(calldatas);
        `,
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
        expected: dedent`
            bytes[] memory calldatas = new bytes[](1);

            // Remove accounts from eip155:1 chain: 0x2000000000000000000000000000000000000002, 0x2000000000000000000000000000000000000001
            calldatas[0] = hex'abcd';

            _updateSafeHarbor(calldatas);
        `,
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
        expected: dedent`
            bytes[] memory calldatas = new bytes[](1);

            // Add accounts to eip155:1 chain: 0x2000000000000000000000000000000000000002, 0x2000000000000000000000000000000000000001
            calldatas[0] = hex'1234';

            _updateSafeHarbor(calldatas);
        `,
    },
])("renders $scenario", ({ updates, expected }) => {
    expect(generateSolidity(updates)).toBe(expected);
});

test("rejects unknown operations", () => {
    expect(() =>
        generateSolidity([
            { fn: "unknownOperation", args: [], calldata: "0x1234" },
        ]),
    ).toThrow("Unknown update");
});

test("renders a mixed operation sequence including Solana identifiers", () => {
    expect(
        generateSolidity([
            {
                fn: "removeChains",
                args: [["eip155:8453"]],
                calldata: "0x1122",
            },
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
                calldata: "0x3344",
            },
            {
                fn: "removeAccounts",
                args: [
                    "eip155:1",
                    ["0x2000000000000000000000000000000000000001"],
                ],
                calldata: "0x5566",
            },
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
                    ],
                ],
                calldata: "0x7788",
            },
        ]),
    ).toBe(dedent`
        bytes[] memory calldatas = new bytes[](4);

        // Remove chains: eip155:8453
        calldatas[0] = hex'1122';

        // Add new solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp with recovery address 29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2 and accounts: So11111111111111111111111111111111111111112
        calldatas[1] = hex'3344';

        // Remove accounts from eip155:1 chain: 0x2000000000000000000000000000000000000001
        calldatas[2] = hex'5566';

        // Add accounts to eip155:1 chain: 0x2000000000000000000000000000000000000002
        calldatas[3] = hex'7788';

        _updateSafeHarbor(calldatas);
    `);
});

test("escapes every Solidity comment terminator without changing calldata", () => {
    expect(
        generateSolidity([
            {
                fn: "removeChains",
                args: [["chain\nrevert(); //"]],
                calldata: "0x1122",
            },
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId: "chain\rrevert(); //",
                            assetRecoveryAddress: "recovery\vrevert(); //",
                            accounts: [
                                {
                                    accountAddress: "account\frevert(); //",
                                    childContractScope: 0,
                                },
                            ],
                        },
                    ],
                ],
                calldata: "0x3344",
            },
            {
                fn: "removeAccounts",
                args: [
                    "chain\u0085revert(); //",
                    ["account\u2028revert(); //"],
                ],
                calldata: "0x5566",
            },
            {
                fn: "addAccounts",
                args: [
                    "chain\r\nrevert(); //",
                    [
                        {
                            accountAddress: "account\u2029revert(); //",
                            childContractScope: 2,
                        },
                    ],
                ],
                calldata: "0x7788",
            },
        ]),
    ).toBe(dedent`
        bytes[] memory calldatas = new bytes[](4);

        // Remove chains: chain\\u000arevert(); //
        calldatas[0] = hex'1122';

        // Add new chain\\u000drevert(); // with recovery address recovery\\u000brevert(); // and accounts: account\\u000crevert(); //
        calldatas[1] = hex'3344';

        // Remove accounts from chain\\u0085revert(); // chain: account\\u2028revert(); //
        calldatas[2] = hex'5566';

        // Add accounts to chain\\u000d\\u000arevert(); // chain: account\\u2029revert(); //
        calldatas[3] = hex'7788';

        _updateSafeHarbor(calldatas);
    `);
});

test("trims each Solidity line while preserving internal spacing and blank lines", () => {
    const code = generateSolidity([
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
        dedent`
            bytes[] memory calldatas = new bytes[](2);

            // Remove chains: eip155:1
            calldatas[0] = hex'1234';

            // Remove chains: eip155:8453
            calldatas[1] = hex'abcd';

            _updateSafeHarbor(calldatas);
        `,
    );
});
