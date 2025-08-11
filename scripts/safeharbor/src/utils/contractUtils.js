import { ethers } from "ethers";
import { AGREEMENT_ADDRESS } from "../constants.js";
import { AGREEMENTV2_ABI as AGREEMENT_ABI } from "../abis.js";

/**
 * Create and return an ethers.js JSON-RPC provider configured from the ETH_RPC_URL environment variable.
 *
 * Throws an Error if ETH_RPC_URL is not set.
 *
 * @return {ethers.providers.JsonRpcProvider} JSON-RPC provider connected to the URL from ETH_RPC_URL.
 */
export function createProvider() {
    if (!process.env.ETH_RPC_URL) {
        throw new Error("ETH_RPC_URL environment variable is not set");
    }
    return new ethers.providers.JsonRpcProvider(process.env.ETH_RPC_URL);
}

/**
 * Create contract instances bound to the given Ethereum provider.
 *
 * Returns an object with an `agreement` property containing an ethers.Contract
 * for AGREEMENT_ADDRESS using AGREEMENT_ABI connected to the provided provider.
 *
 * @return {{agreement: import('ethers').Contract}} The created contract instances.
 */
export function createContractInstances(provider) {
    const agreement = new ethers.Contract(
        AGREEMENT_ADDRESS,
        AGREEMENT_ABI,
        provider,
    );
    return { agreement };
}
