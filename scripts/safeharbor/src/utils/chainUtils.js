import {
    ETHEREUM_ASSET_RECOVERY_ADDRESS,
    BASE_ASSET_RECOVERY_ADDRESS,
    ARBITRUM_ASSET_RECOVERY_ADDRESS,
    SOLANA_ASSET_RECOVERY_ADDRESS,
    OPTIMISM_ASSET_RECOVERY_ADDRESS,
    UNICHAIN_ASSET_RECOVERY_ADDRESS,
} from "../constants.js";

// Chain ID mapping
export const CHAIN_IDS = {
    ETHEREUM: "eip155:1",
    BASE: "eip155:8453",
    GNOSIS: "eip155:100",
    ARBITRUM: "eip155:42161",
    SOLANA: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
    OPTIMISM: "eip155:10",
    UNICHAIN: "eip155:130",
};

// Reverse mapping for chain ID to name
export const CHAIN_NAMES = Object.entries(CHAIN_IDS).reduce(
    (acc, [name, id]) => {
        acc[id] = name;
        return acc;
    },
    {},
);

// Get chain ID from chain name
export function getChainId(chain) {
    return CHAIN_IDS[chain] || 0;
}

// Get chain name from chain ID
export function getChainName(chainId) {
    return CHAIN_NAMES[chainId] || "UNKNOWN";
}

// Get asset recovery address for a chain
export function getAssetRecoveryAddress(chain) {
    switch (chain) {
        case "ETHEREUM":
            return ETHEREUM_ASSET_RECOVERY_ADDRESS;
        case "BASE":
            return BASE_ASSET_RECOVERY_ADDRESS;
        case "ARBITRUM":
            return ARBITRUM_ASSET_RECOVERY_ADDRESS;
        case "SOLANA":
            return SOLANA_ASSET_RECOVERY_ADDRESS;
        case "OPTIMISM":
            return OPTIMISM_ASSET_RECOVERY_ADDRESS;
        case "UNICHAIN":
            return UNICHAIN_ASSET_RECOVERY_ADDRESS;
        default:
            throw new Error(
                `No asset recovery address defined for chain: ${chain}`,
            );
    }
}
