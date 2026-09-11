import { expect, test } from "vitest";
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

test.each([
    {
        diagnostic: {
            code: "DUPLICATE_SHEET_HEADERS",
            context: { duplicateHeaders: ["Status", "Address"] },
        },
        message: "Duplicate CSV headers: Status, Address",
    },
    {
        diagnostic: {
            code: "INVALID_EVM_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:8453",
                isNewChain: true,
                onChainRecoveryAddress: undefined,
                sheetRecoveryAddress: "invalid",
            },
        },
        message:
            "Invalid EVM Asset Recovery Address for chain 'eip155:8453'. On-chain: not registered; Safeharbor Sheet: invalid",
    },
    {
        diagnostic: {
            code: "INVALID_EVM_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:8453",
                isNewChain: false,
                onChainRecoveryAddress: "invalid",
                sheetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        },
        message:
            "Invalid EVM Asset Recovery Address for chain 'eip155:8453'. On-chain: invalid; Safeharbor Sheet: 0x1000000000000000000000000000000000000001",
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
        message:
            "Invalid content type. Expected CSV data. Please check the URL format.",
    },
])("formats $diagnostic.code", ({ diagnostic, message }) => {
    expect(formatDiagnostic(diagnostic)).toBe(message);
});

test("renders bigint scopes without changing raw diagnostic context", () => {
    const diagnostic = {
        code: "INVALID_NEW_CHAIN_ACCOUNTS",
        context: {
            chainId: "eip155:8453",
            accounts: [{ accountAddress: "", childContractScope: 0n }],
        },
    };

    expect(formatDiagnostic(diagnostic)).toBe(
        'Problematic accounts found in chain eip155:8453: [{"accountAddress":"","childContractScope":"0"}]',
    );
    expect(diagnostic).toEqual({
        code: "INVALID_NEW_CHAIN_ACCOUNTS",
        context: {
            chainId: "eip155:8453",
            accounts: [{ accountAddress: "", childContractScope: 0n }],
        },
    });
});
