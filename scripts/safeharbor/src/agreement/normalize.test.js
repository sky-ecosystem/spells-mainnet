import { describe, expect, test } from "vitest";
import { normalizeOnChainState } from "./normalize.js";

describe("normalizeOnChainState", () => {
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
