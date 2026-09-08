import { describe, expect, test } from "vitest";
import {
    createRecoveryAddressValidator,
    createStateValidators,
} from "../src/validateState.js";

describe("recovery address comparison", () => {
    test.each([
        {
            scenario: "lowercase and checksummed EVM addresses match",
            chainId: "eip155:1",
            onchainAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            csvAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "checksummed and lowercase EVM addresses match",
            chainId: "eip155:8453",
            onchainAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            csvAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "different valid EVM addresses mismatch",
            chainId: "eip155:1",
            onchainAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            csvAddress: "0x1000000000000000000000000000000000000001",
            warning: "Asset Recovery Address mismatch",
        },
        {
            scenario: "an invalid CSV checksum is not normalized away",
            chainId: "eip155:1",
            onchainAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            csvAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "an invalid on-chain checksum is not normalized away",
            chainId: "eip155:1",
            onchainAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            csvAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "a malformed EVM address produces a validation warning",
            chainId: "eip155:1",
            onchainAddress: "0x1000000000000000000000000000000000000001",
            csvAddress: "not-an-address",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "identical malformed EVM addresses are still invalid",
            chainId: "eip155:1",
            onchainAddress: "not-an-address",
            csvAddress: "not-an-address",
            warning: "Invalid EVM Asset Recovery Address",
        },
        {
            scenario: "identical Solana identifiers match",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            onchainAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            csvAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "a Solana case difference is a mismatch",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            onchainAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            csvAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: "Asset Recovery Address mismatch",
        },
        {
            scenario: "other non-EVM identifiers match exactly",
            chainId: "cosmos:cosmoshub-4",
            onchainAddress: "recovery-identifier",
            csvAddress: "recovery-identifier",
            warning: null,
        },
        {
            scenario: "other non-EVM case differences remain mismatches",
            chainId: "cosmos:cosmoshub-4",
            onchainAddress: "Recovery-identifier",
            csvAddress: "recovery-identifier",
            warning: "Asset Recovery Address mismatch",
        },
    ])("$scenario", ({ chainId, onchainAddress, csvAddress, warning }) => {
        const validateRecoveryAddress = createRecoveryAddressValidator(
            chainId,
            {
                chainName: "CHAIN",
                onchainRecoveryAddress: onchainAddress,
                csvRecoveryAddress: csvAddress,
            },
        );
        const { validateRecoveryAddresses } = createStateValidators(
            { CHAIN: { assetRecoveryAddress: onchainAddress } },
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
            expect(warnings[0]).toContain(onchainAddress);
            expect(warnings[0]).toContain(csvAddress);
        }
    });
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
            expect.stringContaining("Asset Recovery Address mismatch"),
        ]);
        expect(validateKnownChains()).toEqual([
            expect.stringContaining(
                "Unknown chain details in CSV: name='UNKNOWN'",
            ),
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
