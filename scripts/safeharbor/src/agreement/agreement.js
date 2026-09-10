import { Contract, Interface } from "ethers";
// Verified ABI: https://etherscan.io/address/0xf17bB418B4EC251f300Aa3517Cb37349f17697A1#code
import AGREEMENT_V3_ABI from "./abis/agreement.json" with { type: "json" };
import { createChainlogReader } from "./chainlog.js";
import { normalizeOnChainState } from "./normalize.js";

export function createAgreementReader(provider) {
    const getChainlogAddress = createChainlogReader(provider);

    return async function getAgreementState(chainDetails) {
        const agreementInstance = new Contract(
            await getChainlogAddress(AGREEMENT_CHAINLOG_KEY),
            AGREEMENT_V3_ABI,
            provider,
        );
        return normalizeOnChainState(
            await agreementInstance.getDetails(),
            chainDetails,
        );
    };
}

export function encodeUpdates(changes) {
    return changes.map((change) => ({
        ...change,
        calldata: agreementInterface.encodeFunctionData(change.fn, change.args),
    }));
}

const AGREEMENT_CHAINLOG_KEY = "SAFE_HARBOR_AGREEMENT";
const agreementInterface = new Interface(AGREEMENT_V3_ABI);
