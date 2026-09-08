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
        error: "Cannot add chain 'OPTIMISM' without accounts",
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
        error: "Chain 'BASE' must be removed instead of configured without accounts",
    },
])("rejects $scenario", ({ current, desired, chainDetails, error }) => {
    const encoding = vi.spyOn(Interface.prototype, "encodeFunctionData");

    expect(() => generateUpdates(current, desired, chainDetails)).toThrow(
        error,
    );
    expect(encoding).not.toHaveBeenCalled();
});
