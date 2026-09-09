import { expect, test } from "vitest";
import { formatDiagnostic } from "./formatDiagnostic.js";

test("rejects missing template values", () => {
    expect(() =>
        formatDiagnostic({
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: { chainName: "BASE" },
        }),
    ).toThrow("Missing template value: address");
});

test.each(["UNKNOWN_DIAGNOSTIC", "toString"])(
    "rejects unknown diagnostic code %s",
    (code) => {
        expect(() => formatDiagnostic({ code })).toThrow(
            `Unknown diagnostic code: ${code}`,
        );
    },
);

test("inserts placeholder-like and replacement-pattern text literally", () => {
    expect(
        formatDiagnostic({
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: { chainName: "{address}", address: "$& $1 $$" },
        }),
    ).toBe(
        "Duplicate account address in Safeharbor Sheet for chain '{address}': $& $1 $$",
    );
});

test.each([
    {
        diagnostic: {
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: { chainName: "SOLANA", address: "AccountCaseSensitive" },
        },
        message:
            "Duplicate account address in Safeharbor Sheet for chain 'SOLANA': AccountCaseSensitive",
    },
    {
        diagnostic: {
            code: "DUPLICATE_ONCHAIN_ACCOUNT",
            context: { chainName: "SOLANA", address: "AccountCaseSensitive" },
        },
        message:
            "Duplicate account address in on-chain state for chain 'SOLANA': AccountCaseSensitive",
    },
    {
        diagnostic: {
            code: "UNKNOWN_SHEET_CHAIN",
            context: { chainName: "BASE" },
        },
        message:
            "Unknown chain details in Safeharbor Sheet: name='BASE'\nInclude chain details to the chain details tab in the Safeharbor Sheet to add coverage to it.",
    },
    {
        diagnostic: {
            code: "UNKNOWN_ONCHAIN_CHAIN",
            context: { chainId: "eip155:8453" },
        },
        message:
            "Unknown chain details in on-chain state: caip2ChainId='eip155:8453'.\nTo either remove or keep this chain, please add the chain details to the chain details tab in the Safeharbor Sheet.",
    },
    {
        diagnostic: {
            code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
            context: { chainName: "SOLANA" },
        },
        message:
            "Missing on-chain Asset Recovery Address for existing chain 'SOLANA'",
    },
    {
        diagnostic: {
            code: "RECOVERY_ADDRESS_MISMATCH",
            context: {
                chainName: "SOLANA",
                onChainRecoveryAddress: "RecoveryUpperCase",
                sheetRecoveryAddress: "recoveryUpperCase",
            },
        },
        message:
            "Asset Recovery Address mismatch for chain 'SOLANA'.\nOn-chain: RecoveryUpperCase\nSafeharbor Sheet: recoveryUpperCase",
    },
    {
        diagnostic: {
            code: "INVALID_EVM_RECOVERY_ADDRESS",
            context: {
                chainName: "BASE",
                isNewChain: true,
                onChainRecoveryAddress: undefined,
                sheetRecoveryAddress: "invalid",
            },
        },
        message:
            "Invalid EVM Asset Recovery Address for chain 'BASE'. On-chain: not registered; Safeharbor Sheet: invalid",
    },
    {
        diagnostic: {
            code: "INVALID_EVM_RECOVERY_ADDRESS",
            context: {
                chainName: "BASE",
                isNewChain: false,
                onChainRecoveryAddress: "invalid",
                sheetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        },
        message:
            "Invalid EVM Asset Recovery Address for chain 'BASE'. On-chain: invalid; Safeharbor Sheet: 0x1000000000000000000000000000000000000001",
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
            code: "DUPLICATE_CHAIN_NAME",
            context: { chainName: "BASE" },
        },
        message: "Duplicate chain name found in Safeharbor Sheet: BASE",
    },
    {
        diagnostic: {
            code: "DUPLICATE_CHAIN_ID",
            context: { chainId: "eip155:8453" },
        },
        message: "Duplicate chain ID found in Safeharbor Sheet: eip155:8453",
    },
    {
        diagnostic: {
            code: "MISSING_SHEET_HEADERS",
            context: { missingHeaders: ["Status", "Address"] },
        },
        message: "Missing required CSV headers: Status, Address",
    },
    {
        diagnostic: { code: "COMMAND_REQUIRED" },
        message:
            "Error: Command is required\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    },
    {
        diagnostic: {
            code: "UNKNOWN_COMMAND",
            context: { command: "unknown" },
        },
        message:
            "Error: Unknown command 'unknown'\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    },
    {
        diagnostic: { code: "RPC_URL_REQUIRED" },
        message:
            "Error: ETH_RPC_URL environment variable is not set.\nPlease set your Ethereum RPC URL in a .env file or as an environment variable.\nExample: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
    },
    {
        diagnostic: { code: "HTTP_ERROR", context: { status: 503 } },
        message: "HTTP error! status: 503",
    },
    {
        diagnostic: { code: "INVALID_CSV_CONTENT_TYPE" },
        message:
            "Invalid content type. Expected CSV data. Please check the URL format.",
    },
    {
        diagnostic: {
            code: "ADDED_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainName: "BASE" },
        },
        message: "Cannot add chain 'BASE' without accounts",
    },
    {
        diagnostic: {
            code: "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainName: "BASE" },
        },
        message:
            "Chain 'BASE' must be removed instead of configured without accounts",
    },
    {
        diagnostic: {
            code: "INVALID_NEW_CHAIN_ACCOUNTS",
            context: {
                chainName: "BASE",
                accounts: [{ accountAddress: "", childContractScope: 0 }],
            },
        },
        message:
            'Problematic accounts found in chain BASE: [{"accountAddress":"","childContractScope":0}]',
    },
])("formats $diagnostic.code", ({ diagnostic, message }) => {
    expect(formatDiagnostic(diagnostic)).toBe(message);
});

test("renders bigint scopes without changing raw diagnostic context", () => {
    const diagnostic = {
        code: "INVALID_NEW_CHAIN_ACCOUNTS",
        context: {
            chainName: "BASE",
            accounts: [{ accountAddress: "", childContractScope: 0n }],
        },
    };

    expect(formatDiagnostic(diagnostic)).toBe(
        'Problematic accounts found in chain BASE: [{"accountAddress":"","childContractScope":"0"}]',
    );
    expect(diagnostic).toEqual({
        code: "INVALID_NEW_CHAIN_ACCOUNTS",
        context: {
            chainName: "BASE",
            accounts: [{ accountAddress: "", childContractScope: 0n }],
        },
    });
});
