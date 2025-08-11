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

/**
 * Return the canonical chain ID for a given chain name.
 * If the name is not recognized, returns the sentinel "unknown:0".
 * @param {string} chain - Chain name (e.g. "ETHEREUM", "SOLANA").
 * @returns {string} The matching chain ID, or "unknown:0" when no match exists.
 */
export function getChainId(chain) {
    return CHAIN_IDS[chain] ?? "unknown:0";
}

/**
 * Return the canonical chain name for a given chain ID.
 *
 * @param {string} chainId - Chain identifier (e.g. "eip155:1", "solana:5eykt4UsF...").
 * @return {string} The corresponding chain name (e.g. "ETHEREUM"), or `"UNKNOWN"` if the ID is not recognized.
 */
export function getChainName(chainId) {
    return CHAIN_NAMES[chainId] ?? "UNKNOWN";
}

/**
 * Return the asset-recovery address for a supported chain.
 *
 * Accepted chain names: "ETHEREUM", "BASE", "ARBITRUM", "SOLANA", "OPTIMISM", "UNICHAIN".
 *
 * @param {string} chain - Chain name (one of the accepted values).
 * @returns {string} The asset recovery address for the specified chain.
 * @throws {Error} If no address is defined for the provided chain.
 */
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
