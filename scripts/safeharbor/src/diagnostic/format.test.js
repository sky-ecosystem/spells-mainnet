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
            code: "INVALID_SHEET_FACTORY_FLAG",
            context: {
                chainName: "ETHEREUM",
                address: "A",
                column: "isFactory",
                value: "TRU",
            },
        },
        message:
            "Invalid factory flag in Safeharbor Sheet for chain 'ETHEREUM', account 'A': isFactory='TRU'; expected TRUE, FALSE, or blank",
    },
    {
        diagnostic: {
            code: "MISSING_SHEET_ACCOUNT_ADDRESS",
            context: { chainName: "ETHEREUM" },
        },
        message:
            "Missing active account address in Safeharbor Sheet for chain 'ETHEREUM'",
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
            code: "DUPLICATE_SHEET_ACCOUNT",
            context: {
                chainName: "SOLANA",
                address: "AccountCaseSensitive",
                firstScope: 0,
                duplicateScope: 2,
            },
        },
        message:
            "Duplicate account address in Safeharbor Sheet for chain 'SOLANA': AccountCaseSensitive; first scope=0, duplicate scope=2",
    },
    {
        diagnostic: {
            code: "DUPLICATE_ONCHAIN_ACCOUNT",
            context: {
                chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                address: "AccountCaseSensitive",
                firstScope: 0n,
                duplicateScope: 2n,
            },
        },
        message:
            "Duplicate account address in on-chain state for chain 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp': AccountCaseSensitive; first scope=0, duplicate scope=2",
    },
    {
        diagnostic: {
            code: "UNKNOWN_SHEET_CHAIN",
            context: { chainName: "BASE" },
        },
        message: dedent`
            Unknown chain details in Safeharbor Sheet: name='BASE'
            Include chain details to the chain details tab in the Safeharbor Sheet to add coverage to it.
        `,
    },
    {
        diagnostic: {
            code: "UNKNOWN_ONCHAIN_CHAIN",
            context: { chainId: "eip155:8453" },
        },
        message: dedent`
            Unknown chain details in on-chain state: caip2ChainId='eip155:8453'.
            To either remove or keep this chain, please add the chain details to the chain details tab in the Safeharbor Sheet.
        `,
    },
    {
        diagnostic: {
            code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
            context: { chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp" },
        },
        message:
            "Missing on-chain Asset Recovery Address for existing chain 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'",
    },
    {
        diagnostic: {
            code: "RECOVERY_ADDRESS_MISMATCH",
            context: {
                chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                onChainRecoveryAddress: "RecoveryUpperCase",
                sheetRecoveryAddress: "recoveryUpperCase",
            },
        },
        message: dedent`
            Asset Recovery Address mismatch for chain 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'.
            On-chain: RecoveryUpperCase
            Safeharbor Sheet: recoveryUpperCase
        `,
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
            code: "DUPLICATE_CHAIN_NAME",
            context: {
                chainName: "BASE",
                firstChainId: "eip155:8453",
                duplicateChainId: "eip155:1",
            },
        },
        message:
            "Duplicate chain name found in Safeharbor Sheet: name='BASE', first='eip155:8453', duplicate='eip155:1'",
    },
    {
        diagnostic: {
            code: "DUPLICATE_CHAIN_ID",
            context: {
                chainId: "eip155:8453",
                firstChainName: "BASE",
                duplicateChainName: "OTHER",
            },
        },
        message:
            "Duplicate chain ID found in Safeharbor Sheet: chainId='eip155:8453', first='BASE', duplicate='OTHER'",
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
        message: dedent`
            Error: Command is required
            Available commands: generate, inspect, verify
            Usage: npm run <command>
        `,
    },
    {
        diagnostic: {
            code: "UNKNOWN_COMMAND",
            context: { command: "unknown" },
        },
        message: dedent`
            Error: Unknown command 'unknown'
            Available commands: generate, inspect, verify
            Usage: npm run <command>
        `,
    },
    {
        diagnostic: { code: "RPC_URL_REQUIRED" },
        message: dedent`
            Error: ETH_RPC_URL environment variable is not set.
            Please set your Ethereum RPC URL in a .env file or as an environment variable.
            Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
        `,
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
            context: { chainId: "eip155:8453" },
        },
        message: "Cannot add chain 'eip155:8453' without accounts",
    },
    {
        diagnostic: {
            code: "EXISTING_CHAIN_WITHOUT_ACCOUNTS",
            context: { chainId: "eip155:8453" },
        },
        message:
            "Chain 'eip155:8453' must be removed instead of configured without accounts",
    },
    {
        diagnostic: {
            code: "INVALID_NEW_CHAIN_ACCOUNTS",
            context: {
                chainId: "eip155:8453",
                accounts: [{ accountAddress: "", childContractScope: 0 }],
            },
        },
        message:
            'Problematic accounts found in chain eip155:8453: [{"accountAddress":"","childContractScope":0}]',
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
