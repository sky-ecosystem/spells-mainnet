import { describe, expect, test } from "vitest";
import { validateStates } from "./validateStates.js";

const sheetChainDetails = {
    name: {
        "eip155:1": "ETHEREUM",
        "eip155:8453": "BASE",
        "eip155:137": "POLYGON",
        "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "SOLANA",
    },
};

describe("state validation", () => {
    test("aggregates source warnings and skips invalid recovery pairs while retaining unrelated mismatches", () => {
        expect(
            validateStates({
                agreementOnChainResult: {
                    value: {
                        "eip155:1": {
                            accounts: [],
                            assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                        },
                        "eip155:8453": {
                            accounts: [],
                            assetRecoveryAddress: "invalid-on-chain-address",
                        },
                        "eip155:137": {
                            accounts: [],
                            assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                        },
                    },
                    warnings: [
                        {
                            code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
                            context: { chainId: "eip155:8453" },
                        },
                    ],
                },
                sheetResult: {
                    value: {
                        "eip155:1": {
                            accounts: [],
                            assetRecoveryAddress: "invalid-sheet-address",
                        },
                        "eip155:8453": {
                            accounts: [],
                            assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
                        },
                        "eip155:137": {
                            accounts: [],
                            assetRecoveryAddress: "0x1000000000000000000000000000000000000003",
                        },
                    },
                    warnings: [],
                },
                sheetChainDetailsResult: {
                    value: sheetChainDetails,
                    warnings: [
                        {
                            code: "INVALID_SHEET_RECOVERY_ADDRESS",
                            context: { chainId: "eip155:1", address: "invalid-sheet-address" },
                        },
                    ],
                },
            }),
        ).toStrictEqual([
            {
                code: "INVALID_SHEET_RECOVERY_ADDRESS",
                context: { chainId: "eip155:1", address: "invalid-sheet-address" },
            },
            {
                code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainId: "eip155:8453" },
            },
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "eip155:137",
                    onChainRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    sheetRecoveryAddress: "0x1000000000000000000000000000000000000003",
                },
            },
        ]);
    });

    test("uses each call's recovery data without retaining previous inputs", () => {
        const matchingState = {
            "eip155:1": {
                accounts: [],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        };
        expect(
            validateRecoveryStates(matchingState, {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            }),
        ).toEqual([]);
        expect(
            validateRecoveryStates(
                {
                    "eip155:8453": {
                        accounts: [],
                        assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
                    },
                },
                {
                    "eip155:8453": {
                        accounts: [],
                        assetRecoveryAddress: "0x1000000000000000000000000000000000000003",
                    },
                },
            ),
        ).toEqual([
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "eip155:8453",
                    onChainRecoveryAddress: "0x1000000000000000000000000000000000000002",
                    sheetRecoveryAddress: "0x1000000000000000000000000000000000000003",
                },
            },
        ]);
        expect(
            validateRecoveryStates(matchingState, {
                "eip155:1": {
                    accounts: [],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            }),
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
            scenario: "a new Solana chain has no current recovery address to compare",
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
                    assetRecoveryAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
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
                    assetRecoveryAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
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
                    assetRecoveryAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
            sheetAddress: "0x1000000000000000000000000000000000000001",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "eip155:1",
                    onChainRecoveryAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                    sheetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            },
        },
        {
            scenario: "identical Solana identifiers match",
            chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
            agreementOnChainState: {
                "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": {
                    accounts: [],
                    assetRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
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
                    assetRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
            sheetAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
            warning: {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    onChainRecoveryAddress: "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    sheetRecoveryAddress: "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
        },
    ])("$scenario", ({ chainId, agreementOnChainState, sheetAddress, warning }) => {
        expect(
            validateRecoveryStates(agreementOnChainState, {
                [chainId]: {
                    accounts: [],
                    assetRecoveryAddress: sheetAddress,
                },
            }),
        ).toEqual(warning ? [warning] : []);
    });
});

function validateRecoveryStates(agreementOnChainState, sheetState) {
    return validateStates({
        sheetChainDetailsResult: { value: sheetChainDetails, warnings: [] },
        agreementOnChainResult: { value: agreementOnChainState, warnings: [] },
        sheetResult: { value: sheetState, warnings: [] },
    });
}
