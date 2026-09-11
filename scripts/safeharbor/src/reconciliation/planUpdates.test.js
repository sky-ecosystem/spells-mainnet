import { expect, test } from "vitest";
import { planUpdates } from "./planUpdates.js";

test.each([" ", false, -1, 4, 0.5, "0x", "1.0000000000000001"])(
    "rejects an invalid new-chain scope %s",
    (childContractScope) => {
        expect(() =>
            planUpdates(
                {},
                {
                    "eip155:10": {
                        accounts: [{ accountAddress: "A", childContractScope }],
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000004",
                    },
                },
            ),
        ).toThrowError(
            expect.objectContaining({
                diagnostic: {
                    code: "INVALID_NEW_CHAIN_ACCOUNTS",
                    context: {
                        chainId: "eip155:10",
                        accounts: [{ accountAddress: "A", childContractScope }],
                    },
                },
            }),
        );
    },
);

test.each([0, 1, 2, 3, 0n, "1", "0x2", "0X03"])(
    "preserves supported new-chain scope %s and its type",
    (childContractScope) => {
        expect(
            planUpdates(
                {},
                {
                    "eip155:10": {
                        accounts: [{ accountAddress: "A", childContractScope }],
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000004",
                    },
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
test("rejects missing new-chain accounts before later invalid accounts", () => {
    expect(() =>
        planUpdates(
            {},
            {
                "eip155:10": { assetRecoveryAddress: "recovery" },
                "eip155:8453": {
                    accounts: [{ accountAddress: "", childContractScope: 4 }],
                    assetRecoveryAddress: "other-recovery",
                },
            },
        ),
    ).toThrowError(
        expect.objectContaining({
            diagnostic: {
                code: "ADDED_CHAIN_WITHOUT_ACCOUNTS",
                context: { chainId: "eip155:10" },
            },
        }),
    );
});

test("rejects null desired accounts for an existing chain", () => {
    expect(() =>
        planUpdates(
            {
                "eip155:1": {
                    accounts: [{ accountAddress: "A", childContractScope: 0n }],
                    assetRecoveryAddress: "recovery",
                },
            },
            {
                "eip155:1": {
                    accounts: null,
                    assetRecoveryAddress: "recovery",
                },
            },
        ),
    ).toThrowError(
        expect.objectContaining({
            diagnostic: {
                code: "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
                context: { chainId: "eip155:1" },
            },
        }),
    );
});

test.each([
    {
        scenario: "adding a new chain without accounts",
        current: {},
        desired: {
            "eip155:10": {
                accounts: [],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000004",
            },
        },
        diagnostic: {
            code: "ADDED_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainId: "eip155:10" },
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
        desired: {
            "eip155:8453": {
                accounts: [],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000002",
            },
        },
        diagnostic: {
            code: "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainId: "eip155:8453" },
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
            "eip155:8453": {
                accounts: [
                    {
                        accountAddress:
                            "0x3000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000002",
            },
            "eip155:10": {
                accounts: [{ accountAddress: "", childContractScope: 0 }],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000004",
            },
        },
        diagnostic: {
            code: "INVALID_NEW_CHAIN_ACCOUNTS",
            context: {
                chainId: "eip155:10",
                accounts: [{ accountAddress: "", childContractScope: 0 }],
            },
        },
    },
])("rejects $scenario", ({ current, desired, diagnostic }) => {
    let failure;
    try {
        planUpdates(current, desired);
    } catch (error) {
        failure = error;
    }
    expect(failure).toBeInstanceOf(Error);
    expect(failure.diagnostic).toEqual(diagnostic);
});
