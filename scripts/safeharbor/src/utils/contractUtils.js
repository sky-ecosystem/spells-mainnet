import { Contract, encodeBytes32String, JsonRpcProvider } from "ethers";
import { AGREEMENT_V3_ABI as AGREEMENT_ABI, CHAINLOG_ABI } from "../abis.js";

const CHAINLOG_ADDRESS = "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F";
const AGREEMENT_CHAINLOG_KEY = "SAFE_HARBOR_AGREEMENT";

export async function createAgreementInstance(rpcUrl) {
    const provider = new JsonRpcProvider(rpcUrl);
    const chainlog = new Contract(CHAINLOG_ADDRESS, CHAINLOG_ABI, provider);
    const agreementAddress = await chainlog["getAddress(bytes32)"](
        encodeBytes32String(AGREEMENT_CHAINLOG_KEY),
    );

    const agreement = new Contract(agreementAddress, AGREEMENT_ABI, provider);
    return agreement;
}
