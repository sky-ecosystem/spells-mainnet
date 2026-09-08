export const diagnosticTemplates = {
    DUPLICATE_SHEET_ACCOUNT:
        "Duplicate account address in Safeharbor Sheet for chain '{chainName}': {address}",
    DUPLICATE_ONCHAIN_ACCOUNT:
        "Duplicate account address in on-chain state for chain '{chainName}': {address}",
    UNKNOWN_SHEET_CHAIN:
        "Unknown chain details in Safeharbor Sheet: name='{chainName}'\nInclude chain details to the chain details tab in the Safeharbor Sheet to add coverage to it.",
    UNKNOWN_ONCHAIN_CHAIN:
        "Unknown chain details in on-chain state: caip2ChainId='{chainId}'.\nTo either remove or keep this chain, please add the chain details to the chain details tab in the Safeharbor Sheet.",
    MISSING_ONCHAIN_RECOVERY_ADDRESS:
        "Missing on-chain Asset Recovery Address for existing chain '{chainName}'",
    RECOVERY_ADDRESS_MISMATCH:
        "Asset Recovery Address mismatch for chain '{chainName}'.\nOn-chain: {onchainRecoveryAddress}\nSafeharbor Sheet: {sheetRecoveryAddress}",
    INVALID_EVM_RECOVERY_ADDRESS:
        "Invalid EVM Asset Recovery Address for chain '{chainName}'. On-chain: {onchainRecoveryAddress}; Safeharbor Sheet: {sheetRecoveryAddress}",
    INCOMPLETE_CHAIN_METADATA:
        "Incomplete chain details in Safeharbor Sheet: name='{chainName}', chainId='{chainId}'; missing {missingFields}",
    DUPLICATE_CHAIN_NAME:
        "Duplicate chain name found in Safeharbor Sheet: {chainName}",
    DUPLICATE_CHAIN_ID:
        "Duplicate chain ID found in Safeharbor Sheet: {chainId}",
    MISSING_CSV_HEADERS: "Missing required CSV headers: {missingHeaders}",
    COMMAND_REQUIRED:
        "Error: Command is required\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    UNKNOWN_COMMAND:
        "Error: Unknown command '{command}'\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    RPC_URL_REQUIRED:
        "Error: ETH_RPC_URL environment variable is not set.\nPlease set your Ethereum RPC URL in a .env file or as an environment variable.\nExample: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
    HTTP_ERROR: "HTTP error! status: {status}",
    INVALID_CSV_CONTENT_TYPE:
        "Invalid content type. Expected CSV data. Please check the URL format.",
    ADDED_CHAIN_WITHOUT_ACCOUNTS:
        "Cannot add chain '{chainName}' without accounts",
    EXISTING_CHAIN_WITHOUT_ACCOUNTS:
        "Chain '{chainName}' must be removed instead of configured without accounts",
    INVALID_NEW_CHAIN_ACCOUNTS:
        "Problematic accounts found in chain {chainName}: {accounts}",
};

export function formatDiagnostic({ code, context = {} }) {
    if (!Object.hasOwn(diagnosticTemplates, code)) {
        throw new Error(`Unknown diagnostic code: ${code}`);
    }
    return renderTemplate(diagnosticTemplates[code], {
        ...context,
        ...formatContext[code]?.(context),
    });
}

const formatContext = {
    INVALID_EVM_RECOVERY_ADDRESS: (context) => ({
        onchainRecoveryAddress: context.isNewChain
            ? "not registered"
            : context.onchainRecoveryAddress,
    }),
    INCOMPLETE_CHAIN_METADATA: (context) => ({
        missingFields: context.missingFields.join(", "),
    }),
    MISSING_CSV_HEADERS: (context) => ({
        missingHeaders: context.missingHeaders.join(", "),
    }),
    INVALID_NEW_CHAIN_ACCOUNTS: (context) => ({
        accounts: JSON.stringify(context.accounts, (_key, value) =>
            typeof value === "bigint" ? value.toString() : value,
        ),
    }),
};

function renderTemplate(template, values) {
    return template.replace(/\{(\w+)\}/g, (_, key) => {
        if (!Object.hasOwn(values, key)) {
            throw new Error(`Missing template value: ${key}`);
        }
        return String(values[key]);
    });
}
