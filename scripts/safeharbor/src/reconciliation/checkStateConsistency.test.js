import { describe, expect, test } from "vitest";
import { checkStateConsistency } from "./checkStateConsistency.js";

test.each(["__proto__", "constructor", "toString"])(
    "does not read inherited recovery metadata for %s",
    (chainName) => {
        expect(
            checkStateConsistency(
                {},
                {
                    "eip155:1": [
                        { accountAddress: "A", childContractScope: 0 },
                    ],
                },
                {
                    caip2ChainId: { [chainName]: "eip155:1" },
                    assetRecoveryAddress: {},
                    name: { "eip155:1": chainName },
                },
            ),
        ).toEqual([]);
    },
);

describe("recovery address comparison", () => {
    test("reports a missing on-chain recovery address even when the Sheet address is absent", () => {
        expect(
            checkStateConsistency(
                {
                    "eip155:1": {
                        accounts: [],
                        assetRecoveryAddress: undefined,
                    },
                },
                { "eip155:1": [] },
                {
                    caip2ChainId: { ETHEREUM: "eip155:1" },
                    assetRecoveryAddress: {},
                    name: { "eip155:1": "ETHEREUM" },
                },
            ),
        ).toEqual([
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainId: "eip155:1" },
            },
        ]);
    });

    test("uses each call's recovery data without retaining previous inputs", () => {
        const matchingState = {
            "eip155:1": {
                accounts: [],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        };
        const sheetChainDetails = {
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
                { "eip155:1": [] },
                sheetChainDetails,
            ),
        ).toEqual([]);
        expect(
            checkStateConsistency(
                {
                    "eip155:8453": {
                        accounts: [],
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                    },
                },
                { "eip155:8453": [] },
                sheetChainDetails,
            ),
        ).toEqual([
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "eip155:8453",
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
                { "eip155:1": [] },
                sheetChainDetails,
            ),
        ).toEqual([]);
    });

    test.each([
        {
            scenario: "a new chain accepts a lowercase EVM recovery address",
            chainId: "eip155:1",
            agreementOnChainState: {},
            sheetAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
            warning: null,
        },
        {
            scenario: "a new chain accepts a checksummed EVM recovery address",
            chainId: "eip155:1",
            agreementOnChainState: {},
            sheetAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: null,
        },
        {
            scenario: "a new chain rejects an invalid EVM checksum",
            chainId: "eip155:1",
            agreementOnChainState: {},
            sheetAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {},
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {},
            sheetAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: null,
        },
        {
            scenario: "lowercase and checksummed EVM addresses match",
            chainId: "eip155:1",
            agreementOnChainState: {
                "eip155:1": {
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
            agreementOnChainState: {
                "eip155:8453": {
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
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x1000000000000000000000000000000000000001",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
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
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress: "not-an-address",
                },
            },
            sheetAddress: "not-an-address",
            warning: {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainId: "eip155:1",
                    isNewChain: false,
                    onChainRecoveryAddress: "not-an-address",
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        },
        {
            scenario: "identical Solana identifiers match",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            agreementOnChainState: {
                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": {
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
            agreementOnChainState: {
                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": {
                    accounts: [],
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            sheetAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
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
            agreementOnChainState: {
                "cosmos:cosmoshub-4": {
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
            agreementOnChainState: {
                "cosmos:cosmoshub-4": {
                    accounts: [],
                    assetRecoveryAddress: "Recovery-identifier",
                },
            },
            sheetAddress: "recovery-identifier",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "cosmos:cosmoshub-4",
                    onChainRecoveryAddress: "Recovery-identifier",
                    sheetRecoveryAddress: "recovery-identifier",
                },
            },
        },
    ])(
        "$scenario",
        ({ chainId, agreementOnChainState, sheetAddress, warning }) => {
            expect(
                checkStateConsistency(
                    agreementOnChainState,
                    { [chainId]: [] },
                    {
                        caip2ChainId: { CHAIN: chainId },
                        assetRecoveryAddress: { CHAIN: sheetAddress },
                        name: { [chainId]: "CHAIN" },
                    },
                ),
            ).toEqual(warning ? [warning] : []);
        },
    );
});
