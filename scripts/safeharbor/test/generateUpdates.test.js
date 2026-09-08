import { afterEach, expect, test, vi } from "vitest";
import { Interface } from "ethers";
import { generateUpdates } from "../src/generateUpdates.js";

afterEach(() => vi.restoreAllMocks());

// CSV normalization cannot produce a named chain with an empty account array.
// Exercise these defensive checks directly at the diff boundary.
test.each([
    {
        scenario: "adding a new chain without accounts",
        current: {},
        desired: { OPTIMISM: [] },
        chainDetails: {
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
            BASE: {
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
        desired: { BASE: [] },
        chainDetails: {
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
        scenario: "invalid accounts in a later new chain before any encoding",
        current: {
            ETHEREUM: {
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
            BASE: [
                {
                    accountAddress:
                        "0x3000000000000000000000000000000000000001",
                    childContractScope: 0,
                },
            ],
            OPTIMISM: [{ accountAddress: "", childContractScope: 0 }],
        },
        chainDetails: {
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
])("rejects $scenario", ({ current, desired, chainDetails, diagnostic }) => {
    const encoding = vi.spyOn(Interface.prototype, "encodeFunctionData");

    let failure;
    try {
        generateUpdates(current, desired, chainDetails);
    } catch (error) {
        failure = error;
    }
    expect(failure).toBeInstanceOf(Error);
    expect(failure.diagnostic).toEqual(diagnostic);
    expect(encoding).not.toHaveBeenCalled();
});
