import { describe, expect, test } from "vitest";
import { checkStateConsistency } from "./checkStateConsistency.js";

describe("duplicate account validation", () => {
    test.each([
        {
            scenario:
                "repeated current accounts with identical and conflicting scopes on a removed chain",
            current: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            desired: {},
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
            scenario: "conflicting current scopes on a retained chain",
            current: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            desired: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
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
                        duplicateScope: 2n,
                    },
                },
            ],
        },
        {
            scenario: "the same account on different chains",
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
                BASE: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 2n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                },
            },
            desired: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
                BASE: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                ],
            },
            warnings: [],
        },
        {
            scenario: "distinct case-sensitive EVM account strings",
            current: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x8ba1f109551bd432803012645ac136ddd64dba72",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                            childContractScope: 2n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            desired: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x8ba1f109551bd432803012645ac136ddd64dba72",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                        childContractScope: 2,
                    },
                ],
            },
            warnings: [],
        },
        {
            scenario: "distinct case-sensitive Solana account strings",
            current: {
                SOLANA: {
                    accounts: [
                        {
                            accountAddress:
                                "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                            childContractScope: 2n,
                        },
                    ],
                    assetRecoveryAddress:
                        "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
                },
            },
            desired: {
                SOLANA: [
                    {
                        accountAddress:
                            "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                        childContractScope: 2,
                    },
                ],
            },
            warnings: [],
        },
        { scenario: "empty states", current: {}, desired: {}, warnings: [] },
    ])("$scenario", ({ current, desired, warnings }) => {
        const chainDetails = {
            caip2ChainId: {
                ETHEREUM: "eip155:1",
                BASE: "eip155:8453",
                SOLANA: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            },
            assetRecoveryAddress: {
                ETHEREUM: "0x1000000000000000000000000000000000000001",
                BASE: "0x1000000000000000000000000000000000000002",
                SOLANA: "3EKkiwNLWqoUbzFkPrmKbtUB4EweE6f4STzevYUmezeL",
            },
            name: {
                "eip155:1": "ETHEREUM",
                "eip155:8453": "BASE",
                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "SOLANA",
            },
        };

        expect(checkStateConsistency(current, desired, chainDetails)).toEqual(
            warnings,
        );
    });
});

describe("recovery address comparison", () => {
    test("reports a missing on-chain recovery address even when the Sheet address is absent", () => {
        expect(
            checkStateConsistency(
                {
                    ETHEREUM: {
                        accounts: [],
                        assetRecoveryAddress: undefined,
                    },
                },
                { ETHEREUM: [] },
                {
                    caip2ChainId: { ETHEREUM: "eip155:1" },
                    assetRecoveryAddress: {},
                    name: { "eip155:1": "ETHEREUM" },
                },
            ),
        ).toEqual([
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ]);
    });

    test("uses each call's recovery data without retaining previous inputs", () => {
        const matchingState = {
            ETHEREUM: {
                accounts: [],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        };
        const chainDetails = {
            caip2ChainId: { ETHEREUM: "eip155:1", BASE: "eip155:8453" },
            assetRecoveryAddress: {
                ETHEREUM: "0x1000000000000000000000000000000000000001",
                BASE: "0x1000000000000000000000000000000000000003",
            },
            name: { "eip155:1": "ETHEREUM", "eip155:8453": "BASE" },
        };

        expect(
            checkStateConsistency(
                matchingState,
                { ETHEREUM: [] },
                chainDetails,
            ),
        ).toEqual([]);
        expect(
            checkStateConsistency(
                {
                    BASE: {
                        accounts: [],
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                    },
                },
                { BASE: [] },
                chainDetails,
            ),
        ).toEqual([
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "BASE",
                    onChainRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                    sheetRecoveryAddress:
                        "0x1000000000000000000000000000000000000003",
                },
            },
        ]);
        expect(
            checkStateConsistency(
                matchingState,
                { ETHEREUM: [] },
                chainDetails,
            ),
        ).toEqual([]);
    });

    test.each([
        {
            scenario: "a new chain accepts a lowercase EVM recovery address",
            chainId: "eip155:1",
            onChainState: {},
            sheetAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "a new chain accepts a checksummed EVM recovery address",
            chainId: "eip155:1",
            onChainState: {},
            sheetAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "a new chain rejects an invalid EVM checksum",
            chainId: "eip155:1",
            onChainState: {},
            sheetAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
        },
        {
            scenario: "a new chain rejects a malformed EVM recovery address",
            chainId: "eip155:1",
            onChainState: {},
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        },
        {
            scenario:
                "a new Solana chain has no current recovery address to compare",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            onChainState: {},
            sheetAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "lowercase and checksummed EVM addresses match",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bd432803012645ac136ddd64dba72",
                },
            },
            sheetAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "checksummed and lowercase EVM addresses match",
            chainId: "eip155:8453",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "different valid EVM addresses mismatch",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x1000000000000000000000000000000000000001",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "CHAIN",
                    onChainRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                    sheetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
        },
        {
            scenario:
                "an invalid Safeharbor Sheet checksum is not normalized away",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: false,
                    onChainRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                    sheetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
        },
        {
            scenario: "an invalid on-chain checksum is not normalized away",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: false,
                    onChainRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                    sheetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
        },
        {
            scenario: "a malformed EVM address produces a validation warning",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: false,
                    onChainRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        },
        {
            scenario: "identical malformed EVM addresses are still invalid",
            chainId: "eip155:1",
            onChainState: {
                CHAIN: { accounts: [], assetRecoveryAddress: "not-an-address" },
            },
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "CHAIN",
                    isNewChain: false,
                    onChainRecoveryAddress: "not-an-address",
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        },
        {
            scenario: "identical Solana identifiers match",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            sheetAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "a Solana case difference is a mismatch",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            sheetAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "CHAIN",
                    onChainRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    sheetRecoveryAddress:
                        "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
        },
        {
            scenario: "other non-EVM identifiers match exactly",
            chainId: "cosmos:cosmoshub-4",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress: "recovery-identifier",
                },
            },
            sheetAddress: "recovery-identifier",
            warning: null,
        },
        {
            scenario: "other non-EVM case differences remain mismatches",
            chainId: "cosmos:cosmoshub-4",
            onChainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress: "Recovery-identifier",
                },
            },
            sheetAddress: "recovery-identifier",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "CHAIN",
                    onChainRecoveryAddress: "Recovery-identifier",
                    sheetRecoveryAddress: "recovery-identifier",
                },
            },
        },
    ])("$scenario", ({ chainId, onChainState, sheetAddress, warning }) => {
        expect(
            checkStateConsistency(
                onChainState,
                { CHAIN: [] },
                {
                    caip2ChainId: { CHAIN: chainId },
                    assetRecoveryAddress: { CHAIN: sheetAddress },
                    name: { [chainId]: "CHAIN" },
                },
            ),
        ).toEqual(warning ? [warning] : []);
    });
});
