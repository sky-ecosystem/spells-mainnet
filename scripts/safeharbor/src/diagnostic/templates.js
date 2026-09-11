import { DIAGNOSTIC_CODES as $ } from "./codes.js";
import { dedent } from "../utils/dedent.js";

export const diagnosticTemplates = {
    [$.INVALID_CHAIN_ID]:
        "Chain ID '{chainId}' is not accepted by the Agreement's configured chain validator",
    [$.INVALID_SHEET_FACTORY_FLAG]:
        "Invalid factory flag in Safeharbor Sheet for chain '{chainName}', account '{address}': {column}='{value}'; expected TRUE, FALSE, or blank",
    [$.MISSING_SHEET_ACCOUNT_ADDRESS]:
        "Missing active account address in Safeharbor Sheet for chain '{chainName}'",
    [$.DUPLICATE_SHEET_ACCOUNT]:
        "Duplicate account address in Safeharbor Sheet for chain '{chainName}': {address}; first scope={firstScope}, duplicate scope={duplicateScope}",
    [$.DUPLICATE_ONCHAIN_ACCOUNT]:
        "Duplicate account address in on-chain state for chain '{chainId}': {address}; first scope={firstScope}, duplicate scope={duplicateScope}",
    [$.UNKNOWN_SHEET_CHAIN]: dedent`
        Unknown chain details in Safeharbor Sheet: name='{chainName}'
        Include chain details to the chain details tab in the Safeharbor Sheet to add coverage to it.
    `,
    [$.UNKNOWN_ONCHAIN_CHAIN]: dedent`
        Unknown chain details in on-chain state: caip2ChainId='{chainId}'.
        To either remove or keep this chain, please add the chain details to the chain details tab in the Safeharbor Sheet.
    `,
    [$.MISSING_ONCHAIN_RECOVERY_ADDRESS]:
        "Missing on-chain Asset Recovery Address for existing chain '{chainId}'",
    [$.RECOVERY_ADDRESS_MISMATCH]: dedent`
        Asset Recovery Address mismatch for chain '{chainId}'.
        On-chain: {onChainRecoveryAddress}
        Safeharbor Sheet: {sheetRecoveryAddress}
    `,
    [$.INVALID_EVM_RECOVERY_ADDRESS]:
        "Invalid EVM Asset Recovery Address for chain '{chainId}'. On-chain: {onChainRecoveryAddress}; Safeharbor Sheet: {sheetRecoveryAddress}",
    [$.INCOMPLETE_CHAIN_METADATA]:
        "Incomplete chain details in Safeharbor Sheet: name='{chainName}', chainId='{chainId}'; missing {missingFields}",
    [$.DUPLICATE_CHAIN_NAME]:
        "Duplicate chain name found in Safeharbor Sheet: name='{chainName}', first='{firstChainId}', duplicate='{duplicateChainId}'",
    [$.DUPLICATE_CHAIN_ID]:
        "Duplicate chain ID found in Safeharbor Sheet: chainId='{chainId}', first='{firstChainName}', duplicate='{duplicateChainName}'",
    [$.MISSING_SHEET_HEADERS]: "Missing required CSV headers: {missingHeaders}",
    [$.DUPLICATE_SHEET_HEADERS]: "Duplicate CSV headers: {duplicateHeaders}",
    [$.COMMAND_REQUIRED]: dedent`
        Error: Command is required
        Available commands: generate, inspect, verify
        Usage: npm run <command>
    `,
    [$.UNKNOWN_COMMAND]: dedent`
        Error: Unknown command '{command}'
        Available commands: generate, inspect, verify
        Usage: npm run <command>
    `,
    [$.RPC_URL_REQUIRED]: dedent`
        Error: ETH_RPC_URL environment variable is not set.
        Please set your Ethereum RPC URL in a .env file or as an environment variable.
        Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
    `,
    [$.HTTP_ERROR]: "HTTP error! status: {status}",
    [$.INVALID_CSV_CONTENT_TYPE]:
        "Invalid content type. Expected CSV data. Please check the URL format.",
    [$.ADDED_CHAIN_WITHOUT_ACCOUNTS]:
        "Cannot add chain '{chainId}' without accounts",
    [$.EXISTING_CHAIN_WITHOUT_ACCOUNTS]:
        "Chain '{chainId}' must be removed instead of configured without accounts",
    [$.INVALID_NEW_CHAIN_ACCOUNTS]:
        "Problematic accounts found in chain {chainId}: {accounts}",
};
