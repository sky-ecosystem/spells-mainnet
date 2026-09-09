import { Contract, Interface } from "ethers";
import { AGREEMENT_V3_ABI } from "./abis.js";
import { getChainlogAddress } from "./chainlog.js";
import { normalizeOnChainState } from "./normalize.js";

export function createAgreementReader({ provider }) {
    return async function getAgreementState(chainDetails) {
        const address = await getChainlogAddress(
            provider,
            AGREEMENT_CHAINLOG_KEY,
        );
        const agreementInstance = new Contract(
            address,
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
