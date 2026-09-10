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
                        chainName: "ETHEREUM",
                        address: "0x2000000000000000000000000000000000000001",
                        firstScope: 0n,
                        duplicateScope: 0n,
                    },
                },
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainName: "ETHEREUM",
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
        expect(
            normalizeOnChainState(details, {
                name: {
                    "eip155:1": "ETHEREUM",
                    "eip155:8453": "BASE",
                    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "SOLANA",
                },
            }).warnings,
        ).toEqual(warnings);
    });

    test("reports unknown chains before duplicate accounts in known chains", () => {
        expect(
            normalizeOnChainState(
                {
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
                            accounts: [["B", 0n]],
                        },
                    ],
                },
                { name: { "eip155:1": "ETHEREUM" } },
            ),
        ).toEqual({
            value: {
                ETHEREUM: {
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        { accountAddress: "A", childContractScope: 0n },
                        { accountAddress: "A", childContractScope: 2n },
                    ],
                },
            },
            warnings: [
                {
                    code: "UNKNOWN_ONCHAIN_CHAIN",
                    context: { chainId: "unknown:chain" },
                },
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainName: "ETHEREUM",
                        address: "A",
                        firstScope: 0n,
                        duplicateScope: 2n,
                    },
                },
            ],
        });
    });

    test.each(["__proto__", "constructor", "toString"])(
        "preserves the chain named %s as an own property",
        (chainName) => {
            const result = normalizeOnChainState(
                {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress: "recovery",
                            accounts: [["A", 0n]],
                        },
                    ],
                },
                { name: { "eip155:1": chainName } },
            );
            expect(Object.keys(result.value)).toEqual([chainName]);
            expect(Object.getPrototypeOf(result.value)).toBe(Object.prototype);
            expect(result).toEqual({
                value: {
                    [chainName]: {
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

    test.each(["__proto__", "constructor", "toString"])(
        "does not treat an inherited %s property as known chain metadata",
        (chainId) => {
            expect(
                normalizeOnChainState(
                    {
                        chains: [
                            {
                                caip2ChainId: chainId,
                                assetRecoveryAddress: "recovery",
                                accounts: [["A", 0n]],
                            },
                        ],
                    },
                    { name: {} },
                ),
            ).toEqual({
                value: {},
                warnings: [
                    { code: "UNKNOWN_ONCHAIN_CHAIN", context: { chainId } },
                ],
            });
        },
    );

    test("returns an empty state without warnings", () => {
        expect(normalizeOnChainState({ chains: [] }, { name: {} })).toEqual({
            value: {},
            warnings: [],
        });
    });

    test("returns warnings for unknown on-chain chains", () => {
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

        expect(
            normalizeOnChainState(details, {
                name: { "eip155:1": "ETHEREUM" },
            }),
        ).toEqual({
            value: {
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
            warnings: [
                {
                    code: "UNKNOWN_ONCHAIN_CHAIN",
                    context: { chainId: "eip155:999999" },
                },
            ],
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
        const chainDetails = {
            name: {
                "solana:mainnet": "SOLANA",
                "eip155:1": "ETHEREUM",
            },
        };

        const { value, warnings } = normalizeOnChainState(
            details,
            chainDetails,
        );

        expect(Object.keys(value)).toEqual(["SOLANA", "ETHEREUM"]);
        expect(value).toEqual({
            SOLANA: {
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
            ETHEREUM: {
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
        });
        expect(warnings).toEqual([
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "unknown:first" },
            },
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "unknown:second" },
            },
        ]);
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
        expect(chainDetails).toEqual({
            name: {
                "solana:mainnet": "SOLANA",
                "eip155:1": "ETHEREUM",
            },
        });
    });
});
