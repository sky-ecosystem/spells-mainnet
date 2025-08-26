import { Contract, JsonRpcProvider } from "ethers";
import { AGREEMENT_ADDRESS } from "../constants.js";
import { AGREEMENTV2_ABI as AGREEMENT_ABI } from "../abis.js";

/**
 * Create an ethers Contract instance for the Agreement contract connected to the given RPC URL.
 *
 * @param {string} rpcUrl - JSON-RPC endpoint URL used to create a JsonRpcProvider.
 * @return {Contract} A Contract instance for AGREEMENT_ADDRESS using AGREEMENT_ABI and the provider.
 */
export function createAgreementInstance(rpcUrl) {
    const provider = new JsonRpcProvider(rpcUrl);

    const agreement = new Contract(AGREEMENT_ADDRESS, AGREEMENT_ABI, provider);
    return agreement;
}
