import { describe, expect, test } from "vitest";
import {
    createRecoveryAddressValidator,
    createStateValidators,
    validateState,
} from "../src/validateState.js";

describe("duplicate account validation", () => {
    test.each([
        {
            scenario: "warnings follow the first repeated occurrence",
            current: {},
            desired: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 2,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                ],
            },
            warnings: [
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
            ],
        },
        {
            scenario: "duplicate desired accounts on a new chain",
            current: {},
            desired: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
            },
            warnings: [
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
            ],
        },
        {
            scenario: "conflicting desired scopes on an existing chain",
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
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                ],
            },
            warnings: [
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
            ],
        },
        {
            scenario: "duplicate current accounts on a removed chain",
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
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            desired: {},
            warnings: [
                "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
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
                "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
            ],
        },
        {
            scenario: "multiple duplicate addresses in both sources",
            current: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000002",
                            childContractScope: 0n,
                        },
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000002",
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
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                ],
            },
            warnings: [
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
                "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
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

        expect(validateState(current, desired, chainDetails)).toEqual(warnings);
        const { validateUniqueAccounts } = createStateValidators(
            current,
            desired,
            chainDetails,
        );
        expect(validateUniqueAccounts()).toEqual(warnings);
        expect(validateUniqueAccounts()).toEqual(warnings);
    });
});

describe("recovery address comparison", () => {
    test.each([
        {
            scenario: "a new chain accepts a lowercase EVM recovery address",
            chainId: "eip155:1",
            isNewChain: true,
            onchainState: {},
            csvAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "a new chain accepts a checksummed EVM recovery address",
            chainId: "eip155:1",
            isNewChain: true,
            onchainState: {},
            csvAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "a new chain rejects an invalid EVM checksum",
            chainId: "eip155:1",
            isNewChain: true,
            onchainState: {},
            csvAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "a new chain rejects a malformed EVM recovery address",
            chainId: "eip155:1",
            isNewChain: true,
            onchainState: {},
            csvAddress: "not-an-address",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario:
                "a new Solana chain has no current recovery address to compare",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            isNewChain: true,
            onchainState: {},
            csvAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "lowercase and checksummed EVM addresses match",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bd432803012645ac136ddd64dba72",
                },
            },
            csvAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "checksummed and lowercase EVM addresses match",
            chainId: "eip155:8453",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            csvAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "different valid EVM addresses mismatch",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            csvAddress: "0x1000000000000000000000000000000000000001",
            warning: "Asset Recovery Address mismatch",
        },
        {
            scenario: "an invalid CSV checksum is not normalized away",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            csvAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "an invalid on-chain checksum is not normalized away",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            csvAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "a malformed EVM address produces a validation warning",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            csvAddress: "not-an-address",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "identical malformed EVM addresses are still invalid",
            chainId: "eip155:1",
            isNewChain: false,
            onchainState: {
                CHAIN: { accounts: [], assetRecoveryAddress: "not-an-address" },
            },
            csvAddress: "not-an-address",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "identical Solana identifiers match",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            csvAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "a Solana case difference is a mismatch",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            csvAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: "Asset Recovery Address mismatch",
        },
        {
            scenario: "other non-EVM identifiers match exactly",
            chainId: "cosmos:cosmoshub-4",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress: "recovery-identifier",
                },
            },
            csvAddress: "recovery-identifier",
            warning: null,
        },
        {
            scenario: "other non-EVM case differences remain mismatches",
            chainId: "cosmos:cosmoshub-4",
            isNewChain: false,
            onchainState: {
                CHAIN: {
                    accounts: [],
                    assetRecoveryAddress: "Recovery-identifier",
                },
            },
            csvAddress: "recovery-identifier",
            warning: "Asset Recovery Address mismatch",
        },
    ])(
        "$scenario",
        ({ chainId, isNewChain, onchainState, csvAddress, warning }) => {
            const onchainAddress = onchainState.CHAIN?.assetRecoveryAddress;
            const validateRecoveryAddress = createRecoveryAddressValidator(
                chainId,
                {
                    chainName: "CHAIN",
                    isNewChain,
                    onchainRecoveryAddress: onchainAddress,
                    csvRecoveryAddress: csvAddress,
                },
            );
            const { validateRecoveryAddresses } = createStateValidators(
                onchainState,
                { CHAIN: [] },
                {
                    caip2ChainId: { CHAIN: chainId },
                    assetRecoveryAddress: { CHAIN: csvAddress },
                    name: { [chainId]: "CHAIN" },
                },
            );
            const warnings = validateRecoveryAddresses();

            expect(warnings).toEqual(
                warning ? [expect.stringContaining(warning)] : [],
            );
            expect(validateRecoveryAddress()).toEqual(warnings);
            if (warning) {
                expect(warnings[0]).toContain(
                    onchainAddress ?? "not registered",
                );
                expect(warnings[0]).toContain(csvAddress);
            }
        },
    );
});

describe("known-chain validation", () => {
    test("returns unknown-chain warnings independently of recovery warnings", () => {
        const { validateRecoveryAddresses, validateKnownChains } =
            createStateValidators(
                {
                    ETHEREUM: {
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
                { ETHEREUM: [], UNKNOWN: [] },
                {
                    caip2ChainId: { ETHEREUM: "eip155:1" },
                    assetRecoveryAddress: {
                        ETHEREUM: "0x1000000000000000000000000000000000000002",
                    },
                    name: { "eip155:1": "ETHEREUM" },
                },
            );

        expect(validateRecoveryAddresses()).toEqual([
            "Asset Recovery Address mismatch for chain 'ETHEREUM'.\nOn-chain: 0x1000000000000000000000000000000000000001\nCSV:      0x1000000000000000000000000000000000000002",
        ]);
        expect(validateKnownChains()).toEqual([
            "Unknown chain details in CSV: name='UNKNOWN'\nInclude chain details to the chain details tab in the Google Sheet to add coverage to it.",
        ]);
    });

    test.each([
        ["known chains", { ETHEREUM: [] }],
        ["no desired chains", {}],
    ])("returns no warnings for %s", (_scenario, csvState) => {
        const { validateKnownChains } = createStateValidators({}, csvState, {
            caip2ChainId: { ETHEREUM: "eip155:1" },
            assetRecoveryAddress: {
                ETHEREUM: "0x1000000000000000000000000000000000000001",
            },
            name: { "eip155:1": "ETHEREUM" },
        });

        expect(validateKnownChains()).toEqual([]);
    });

    test("each factory instance captures its own chain metadata", () => {
        const ethereum = createStateValidators(
            {},
            { ETHEREUM: [] },
            {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
        );
        const base = createStateValidators(
            {},
            { ETHEREUM: [] },
            {
                caip2ChainId: { BASE: "eip155:8453" },
                assetRecoveryAddress: {
                    BASE: "0x1000000000000000000000000000000000000002",
                },
                name: { "eip155:8453": "BASE" },
            },
        );

        expect(ethereum.validateKnownChains()).toEqual([]);
        expect(base.validateKnownChains()).toEqual([
            expect.stringContaining(
                "Unknown chain details in CSV: name='ETHEREUM'",
            ),
        ]);
        expect(ethereum.validateKnownChains()).toEqual([]);
    });
});
