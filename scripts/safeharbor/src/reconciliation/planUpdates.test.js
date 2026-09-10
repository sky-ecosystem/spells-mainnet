import { expect, test } from "vitest";
import { planUpdates } from "./planUpdates.js";

test.each([
    "",
    " ",
    "0x",
    "0x4",
    "-1",
    "4",
    "1.0",
    "1e0",
    "1.0000000000000001",
    false,
    true,
    null,
    undefined,
    -1,
    4,
    -1n,
    4n,
    0.5,
    NaN,
    Infinity,
])("rejects an invalid new-chain scope %s", (childContractScope) => {
    expect(() =>
        planUpdates(
            {},
            { "eip155:10": [{ accountAddress: "A", childContractScope }] },
            {
                caip2ChainId: { OPTIMISM: "eip155:10" },
                assetRecoveryAddress: {
                    OPTIMISM: "0x1000000000000000000000000000000000000004",
                },
                name: { "eip155:10": "OPTIMISM" },
            },
        ),
    ).toThrowError(
        expect.objectContaining({
            diagnostic: {
                code: "INVALID_NEW_CHAIN_ACCOUNTS",
                context: {
                    chainName: "OPTIMISM",
                    accounts: [{ accountAddress: "A", childContractScope }],
                },
            },
        }),
    );
});

test.each([
    0,
    1,
    2,
    3,
    0n,
    1n,
    2n,
    3n,
    "0",
    "1",
    "2",
    "3",
    "0x0",
    "0x1",
    "0x2",
    "0x3",
    "0X03",
])(
    "preserves supported new-chain scope %s and its type",
    (childContractScope) => {
        expect(
            planUpdates(
                {},
                { "eip155:10": [{ accountAddress: "A", childContractScope }] },
                {
                    caip2ChainId: { OPTIMISM: "eip155:10" },
                    assetRecoveryAddress: {
                        OPTIMISM: "0x1000000000000000000000000000000000000004",
                    },
                    name: { "eip155:10": "OPTIMISM" },
                },
            ),
        ).toEqual([
            {
                fn: "addChains",
                args: [
                    [
                        {
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000004",
                            accounts: [
                                { accountAddress: "A", childContractScope },
                            ],
                            caip2ChainId: "eip155:10",
                        },
                    ],
                ],
            },
        ]);
    },
);

// CSV normalization cannot produce a named chain with an empty account array.
// Exercise these defensive checks directly at the diff boundary.
test.each([
    {
        scenario: "adding a new chain without accounts",
        current: {},
        desired: { "eip155:10": [] },
        sheetChainDetails: {
            caip2ChainId: { OPTIMISM: "eip155:10" },
            assetRecoveryAddress: {
                OPTIMISM: "0x1000000000000000000000000000000000000004",
            },
            name: { "eip155:10": "OPTIMISM" },
        },
        diagnostic: {
            code: "ADDED_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainName: "OPTIMISM" },
        },
    },
    {
        scenario: "an existing chain without desired accounts",
        current: {
            "eip155:8453": {
                accounts: [
                    {
                        accountAddress:
                            "0x3000000000000000000000000000000000000001",
                        childContractScope: 0n,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000002",
            },
        },
        desired: { "eip155:8453": [] },
        sheetChainDetails: {
            caip2ChainId: { BASE: "eip155:8453" },
            assetRecoveryAddress: {
                BASE: "0x1000000000000000000000000000000000000002",
            },
            name: { "eip155:8453": "BASE" },
        },
        diagnostic: {
            code: "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainName: "BASE" },
        },
    },
    {
        scenario: "invalid accounts in a later new chain",
        current: {
            "eip155:1": {
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
        desired: {
            "eip155:8453": [
                {
                    accountAddress:
                        "0x3000000000000000000000000000000000000001",
                    childContractScope: 0,
                },
            ],
            "eip155:10": [{ accountAddress: "", childContractScope: 0 }],
        },
        sheetChainDetails: {
            caip2ChainId: {
                ETHEREUM: "eip155:1",
                BASE: "eip155:8453",
                OPTIMISM: "eip155:10",
            },
            assetRecoveryAddress: {
                ETHEREUM: "0x1000000000000000000000000000000000000001",
                BASE: "0x1000000000000000000000000000000000000002",
                OPTIMISM: "0x1000000000000000000000000000000000000004",
            },
            name: {
                "eip155:1": "ETHEREUM",
                "eip155:8453": "BASE",
                "eip155:10": "OPTIMISM",
            },
        },
        diagnostic: {
            code: "INVALID_NEW_CHAIN_ACCOUNTS",
            context: {
                chainName: "OPTIMISM",
                accounts: [{ accountAddress: "", childContractScope: 0 }],
            },
        },
    },
])(
    "rejects $scenario",
    ({ current, desired, sheetChainDetails, diagnostic }) => {
        let failure;
        try {
            planUpdates(current, desired, sheetChainDetails);
        } catch (error) {
            failure = error;
        }
        expect(failure).toBeInstanceOf(Error);
        expect(failure.diagnostic).toEqual(diagnostic);
    },
);
