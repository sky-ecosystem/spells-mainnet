import { expect, test } from "vitest";
import { dedent } from "../utils/dedent.js";
import { formatDiagnostic } from "./format.js";

test("rejects missing template values", () => {
    expect(() =>
        formatDiagnostic({
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: { chainName: "BASE" },
        }),
    ).toThrow("Missing template value: address");
});

test("rejects explicitly undefined template values", () => {
    expect(() =>
        formatDiagnostic({
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: {
                chainName: "BASE",
                address: undefined,
                firstScope: 0,
                duplicateScope: 2,
            },
        }),
    ).toThrow("Missing template value: address");
});

test("inserts placeholder-like and replacement-pattern text literally", () => {
    expect(
        formatDiagnostic({
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: {
                chainName: "{address}",
                address: "$& $1 $$",
                firstScope: 0,
                duplicateScope: 2,
            },
        }),
    ).toBe(
        "Duplicate account address in Safeharbor Sheet for chain '{address}': $& $1 $$; first scope=0, duplicate scope=2",
    );
});

test("shows line terminators visibly in a Sheet chain ID diagnostic", () => {
    expect(
        formatDiagnostic({
            code: "SHEET_CHAIN_ID_LINE_TERMINATOR",
            context: {
                chainName: "ETHEREUM",
                chainId: "eip155:1\nrevert(); //\u2028hidden",
            },
        }),
    ).toBe("Line terminator in SafeHarbor Sheet Chain Id for 'ETHEREUM': \"eip155:1\\nrevert(); //\\u2028hidden\"");
});

test.each([
    {
        diagnostic: {
            code: "DUPLICATE_SHEET_EVM_ACCOUNT",
            context: {
                chainName: "ETHEREUM",
                firstAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
                duplicateAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                firstScope: 0,
                duplicateScope: 2,
            },
        },
        message:
            "Equivalent EVM account addresses in Safeharbor Sheet for chain 'ETHEREUM': first='0x8ba1f109551bd432803012645ac136ddd64dba72' (scope=0), duplicate='0x8ba1f109551bD432803012645Ac136ddd64DBA72' (scope=2)",
    },
    {
        diagnostic: {
            code: "DUPLICATE_ONCHAIN_EVM_ACCOUNT",
            context: {
                chainId: "eip155:1",
                firstAddress: "0x8ba1f109551bd432803012645ac136ddd64dba72",
                duplicateAddress: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
                firstScope: 0n,
                duplicateScope: 2n,
            },
        },
        message:
            "Equivalent EVM account addresses in on-chain state for chain 'eip155:1': first='0x8ba1f109551bd432803012645ac136ddd64dba72' (scope=0), duplicate='0x8ba1f109551bD432803012645Ac136ddd64DBA72' (scope=2)",
    },
    {
        diagnostic: {
            code: "INVALID_SHEET_RECOVERY_ADDRESS",
            context: {
                chainName: "SOLANA",
                chainId: "solana:mainnet",
                address: "1",
            },
        },
        message: "Invalid Asset Recovery Address in SafeHarbor Sheet for chain 'SOLANA' (solana:mainnet): 1",
    },
    {
        diagnostic: {
            code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:1",
                address: "invalid",
            },
        },
        message: "Invalid on-chain Asset Recovery Address for chain 'eip155:1': invalid",
    },
    {
        diagnostic: {
            code: "UNSUPPORTED_SHEET_CHAIN_NAMESPACE",
            context: { chainName: "COSMOS", chainId: "cosmos:cosmoshub-4" },
        },
        message:
            "Unsupported chain namespace in SafeHarbor Sheet: name='COSMOS', chainId='cosmos:cosmoshub-4'; expected eip155 or solana",
    },
    {
        diagnostic: {
            code: "INVALID_SHEET_STATUS",
            context: {
                chainName: "ETHEREUM",
                address: "0x2000000000000000000000000000000000000001",
                status: "PAUSED",
            },
        },
        message:
            "Unrecognized status in SafeHarbor Sheet for chain 'ETHEREUM', account '0x2000000000000000000000000000000000000001': 'PAUSED'; expected ACTIVE or DISABLED",
    },
    {
        diagnostic: {
            code: "UNKNOWN_SHEET_CHAIN",
            context: { chainName: "BASE" },
        },
        message: dedent`
            Unknown chain in SafeHarbor Sheet: name='BASE'.
            Add this chain to the 'safe-harbor-asset-recovery' tab before including it in scope.
        `,
    },
    {
        diagnostic: {
            code: "UNKNOWN_ONCHAIN_CHAIN",
            context: { chainId: "eip155:8453" },
        },
        message: dedent`
            Unknown chain in on-chain state: caip2ChainId='eip155:8453'.
            Add this chain to the 'safe-harbor-asset-recovery' tab before keeping or removing it.
        `,
    },
    {
        diagnostic: {
            code: "INVALID_SHEET_ACCOUNT_ADDRESS",
            context: {
                chainName: "ETHEREUM",
                chainId: "eip155:1",
                address: "invalid",
            },
        },
        message: "Invalid account address in SafeHarbor Sheet for chain 'ETHEREUM' (eip155:1): invalid",
    },
    {
        diagnostic: {
            code: "DUPLICATE_SHEET_HEADERS",
            context: { duplicateHeaders: ["Status", "Address"] },
        },
        message: "Duplicate CSV headers: Status, Address",
    },
    {
        diagnostic: {
            code: "INCOMPLETE_CHAIN_METADATA",
            context: {
                chainName: "BASE",
                chainId: "",
                missingFields: ["Chain Id", "Asset Recovery Address"],
            },
        },
        message:
            "Incomplete chain details in Safeharbor Sheet: name='BASE', chainId=''; missing Chain Id, Asset Recovery Address",
    },
    {
        diagnostic: {
            code: "MISSING_SHEET_HEADERS",
            context: { missingHeaders: ["Status", "Address"] },
        },
        message: "Missing required CSV headers: Status, Address",
    },
    {
        diagnostic: { code: "INVALID_CSV_CONTENT_TYPE" },
        message: "Invalid content type. Expected CSV data. Please check the URL format.",
    },
])("formats $diagnostic.code", ({ diagnostic, message }) => {
    expect(formatDiagnostic(diagnostic)).toBe(message);
});
