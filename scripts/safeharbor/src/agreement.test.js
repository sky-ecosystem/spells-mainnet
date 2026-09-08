import { describe, expect, test } from "vitest";
import { normalizeOnchainState } from "./agreement.js";

describe("normalizeOnchainState", () => {
    test("returns an empty state without warnings", () => {
        expect(normalizeOnchainState({ chains: [] }, { name: {} })).toEqual({
            onChainState: {},
            validationWarnings: [],
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
            normalizeOnchainState(details, {
                name: { "eip155:1": "ETHEREUM" },
            }),
        ).toEqual({
            onChainState: {
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
            validationWarnings: [
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

        const { onChainState, validationWarnings } = normalizeOnchainState(
            details,
            chainDetails,
        );

        expect(Object.keys(onChainState)).toEqual(["SOLANA", "ETHEREUM"]);
        expect(onChainState).toEqual({
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
        expect(validationWarnings).toEqual([
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
