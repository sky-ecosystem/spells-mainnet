import { Contract, JsonRpcProvider } from "ethers";
import { AGREEMENT_ADDRESS } from "../constants.js";
import { AGREEMENTV2_ABI as AGREEMENT_ABI } from "../abis.js";

// Create a provider instance
export function createProvider() {
    if (!process.env.ETH_RPC_URL) {
        throw new Error("ETH_RPC_URL environment variable is not set");
    }
    return new JsonRpcProvider(process.env.ETH_RPC_URL);
}

export function createContractInstances(provider) {
    const agreement = new Contract(
        AGREEMENT_ADDRESS,
        AGREEMENT_ABI,
        provider,
    );
    return { agreement };
}
