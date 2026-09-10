import { describe, expect, test } from "vitest";
import { normalizeOnChainState } from "./normalize.js";

describe("normalizeOnChainState", () => {
    test.each([
        {
            scenario: "repeated accounts with identical and conflicting scopes",
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            ["0x2000000000000000000000000000000000000001", 0n],
                            ["0x2000000000000000000000000000000000000001", 0n],
                            ["0x2000000000000000000000000000000000000001", 2n],
                        ],
                    },
                ],
            },
            warnings: [
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "eip155:1",
                        address: "0x2000000000000000000000000000000000000001",
                        firstScope: 0n,
                        duplicateScope: 0n,
                    },
                },
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "eip155:1",
                        address: "0x2000000000000000000000000000000000000001",
                        firstScope: 0n,
                        duplicateScope: 2n,
                    },
                },
            ],
        },
        {
            scenario: "the same account on different chains",
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            ["0x2000000000000000000000000000000000000001", 0n],
                        ],
                    },
                    {
                        caip2ChainId: "eip155:8453",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                        accounts: [
                            ["0x2000000000000000000000000000000000000001", 2n],
                        ],
                    },
                ],
            },
            warnings: [],
        },
        {
            scenario: "distinct case-sensitive EVM account strings",
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            ["0x8ba1f109551bd432803012645ac136ddd64dba72", 0n],
                            ["0x8ba1f109551bD432803012645Ac136ddd64DBA72", 2n],
                        ],
                    },
                ],
            },
            warnings: [],
        },
        {
            scenario: "distinct case-sensitive Solana account strings",
            details: {
                chains: [
                    {
                        caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                        assetRecoveryAddress:
                            "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
                        accounts: [
                            [
                                "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                                0n,
                            ],
                            [
                                "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                                2n,
                            ],
                        ],
                    },
                ],
            },
            warnings: [],
        },
    ])("validates $scenario", ({ details, warnings }) => {
        expect(normalizeOnChainState(details).warnings).toEqual(warnings);
    });

    test("retains all raw chain IDs and diagnoses duplicates without Sheet metadata", () => {
        expect(
            normalizeOnChainState({
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            ["A", 0n],
                            ["A", 2n],
                        ],
                    },
                    {
                        caip2ChainId: "unknown:chain",
                        assetRecoveryAddress: "unknown-recovery",
                        accounts: [
                            ["B", 0n],
                            ["B", 2n],
                        ],
                    },
                ],
            }),
        ).toEqual({
            value: {
                "eip155:1": {
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        { accountAddress: "A", childContractScope: 0n },
                        { accountAddress: "A", childContractScope: 2n },
                    ],
                },
                "unknown:chain": {
                    assetRecoveryAddress: "unknown-recovery",
                    accounts: [
                        { accountAddress: "B", childContractScope: 0n },
                        { accountAddress: "B", childContractScope: 2n },
                    ],
                },
            },
            warnings: [
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "eip155:1",
                        address: "A",
                        firstScope: 0n,
                        duplicateScope: 2n,
                    },
                },
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "unknown:chain",
                        address: "B",
                        firstScope: 0n,
                        duplicateScope: 2n,
                    },
                },
            ],
        });
    });

    test.each(["__proto__", "constructor", "toString"])(
        "preserves the raw chain ID %s as an own property",
        (chainId) => {
            const result = normalizeOnChainState({
                chains: [
                    {
                        caip2ChainId: chainId,
                        assetRecoveryAddress: "recovery",
                        accounts: [["A", 0n]],
                    },
                ],
            });
            expect(Object.keys(result.value)).toEqual([chainId]);
            expect(Object.getPrototypeOf(result.value)).toBe(Object.prototype);
            expect(result).toEqual({
                value: {
                    [chainId]: {
                        assetRecoveryAddress: "recovery",
                        accounts: [
                            { accountAddress: "A", childContractScope: 0n },
                        ],
                    },
                },
                warnings: [],
            });
        },
    );

    test("returns an empty state without warnings", () => {
        expect(normalizeOnChainState({ chains: [] })).toEqual({
            value: {},
            warnings: [],
        });
    });

    test("preserves multiple raw chain IDs without lookup warnings", () => {
        const details = {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
                {
                    caip2ChainId: "eip155:999999",
                    assetRecoveryAddress:
                        "0x10000000000000000000000000000000000000fe",
                    accounts: [
                        ["0x6000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        };

        expect(normalizeOnChainState(details)).toEqual({
            value: {
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
                "eip155:999999": {
                    accounts: [
                        {
                            accountAddress:
                                "0x6000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x10000000000000000000000000000000000000fe",
                },
            },
            warnings: [],
        });
    });

    test("preserves chain and account order, exact values, and inputs", () => {
        const details = {
            chains: [
                {
                    caip2ChainId: "unknown:first",
                    assetRecoveryAddress: "unused-first",
                    accounts: [],
                },
                {
                    caip2ChainId: "solana:mainnet",
                    assetRecoveryAddress: "RecoveryCaseSensitive",
                    accounts: [
                        ["AccountUpperCase", 2n],
                        ["accountUpperCase", 0n],
                    ],
                },
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0xA000000000000000000000000000000000000001", 1n],
                    ],
                },
                {
                    caip2ChainId: "unknown:second",
                    assetRecoveryAddress: "unused-second",
                    accounts: [],
                },
            ],
        };
        const { value, warnings } = normalizeOnChainState(details);

        expect(Object.keys(value)).toEqual([
            "unknown:first",
            "solana:mainnet",
            "eip155:1",
            "unknown:second",
        ]);
        expect(value).toEqual({
            "unknown:first": {
                accounts: [],
                assetRecoveryAddress: "unused-first",
            },
            "solana:mainnet": {
                accounts: [
                    {
                        accountAddress: "AccountUpperCase",
                        childContractScope: 2n,
                    },
                    {
                        accountAddress: "accountUpperCase",
                        childContractScope: 0n,
                    },
                ],
                assetRecoveryAddress: "RecoveryCaseSensitive",
            },
            "eip155:1": {
                accounts: [
                    {
                        accountAddress:
                            "0xA000000000000000000000000000000000000001",
                        childContractScope: 1n,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
            "unknown:second": {
                accounts: [],
                assetRecoveryAddress: "unused-second",
            },
        });
        expect(warnings).toEqual([]);
        expect(details).toEqual({
            chains: [
                {
                    caip2ChainId: "unknown:first",
                    assetRecoveryAddress: "unused-first",
                    accounts: [],
                },
                {
                    caip2ChainId: "solana:mainnet",
                    assetRecoveryAddress: "RecoveryCaseSensitive",
                    accounts: [
                        ["AccountUpperCase", 2n],
                        ["accountUpperCase", 0n],
                    ],
                },
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0xA000000000000000000000000000000000000001", 1n],
                    ],
                },
                {
                    caip2ChainId: "unknown:second",
                    assetRecoveryAddress: "unused-second",
                    accounts: [],
                },
            ],
        });
    });
});
