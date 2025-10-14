import { Contract, JsonRpcProvider } from "ethers";
import { AGREEMENT_ADDRESS } from "../constants.js";
import { AGREEMENTV2_ABI as AGREEMENT_ABI } from "../abis.js";

export function createAgreementInstance(rpcUrl) {
    const provider = new JsonRpcProvider(rpcUrl);

    const agreement = new Contract(AGREEMENT_ADDRESS, AGREEMENT_ABI, provider);
    return agreement;
}
