import { Contract, Interface } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
// Verified ABI: https://etherscan.io/address/0xf17bB418B4EC251f300Aa3517Cb37349f17697A1#code
import AGREEMENT_V3_ABI from "./abis/agreement.json" with { type: "json" };
// Verified ABI: https://etherscan.io/address/0x1eee8E721816CD5A0033FBA6Ba93486C074dD1cB#code
import CHAIN_VALIDATOR_ABI from "./abis/chainValidator.json" with { type: "json" };
import { createChainlogReader } from "./chainlog.js";
import { normalizeOnChainState } from "./normalize.js";

export function createAgreementReader(provider) {
    const getChainlogAddress = createChainlogReader(provider);

    return async function getAgreementState(desiredChainIds) {
        const agreementInstance = new Contract(
            await getChainlogAddress(AGREEMENT_CHAINLOG_KEY),
            AGREEMENT_V3_ABI,
            provider,
        );
        const { value, warnings } = normalizeOnChainState(await agreementInstance.getDetails());
        const newChainIds = desiredChainIds.filter((chainId) => !value[chainId]);
        if (newChainIds.length === 0) {
            return { value, warnings };
        }
        const chainValidatorInstance = new Contract(
            await agreementInstance.getChainValidator(),
            CHAIN_VALIDATOR_ABI,
            provider,
        );
        return {
            value,
            warnings: [...warnings, ...(await checkChainIds(chainValidatorInstance, newChainIds))],
        };
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

async function checkChainIds(chainValidatorInstance, chainIds) {
    const valid = await Promise.all(chainIds.map((chainId) => chainValidatorInstance.isChainValid(chainId)));
    return chainIds
        .filter((_chainId, index) => !valid[index])
        .map((chainId) => ({
            code: $.INVALID_CHAIN_ID,
            context: { chainId },
        }));
}
