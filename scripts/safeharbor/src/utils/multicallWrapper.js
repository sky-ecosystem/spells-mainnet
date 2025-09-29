import { Interface } from "ethers";
import { MULTICALL_ABI } from "../abis.js";
import { AGREEMENT_ADDRESS, MULTICALL_ADDRESS } from "../constants.js";

const multicallInterface = new Interface(MULTICALL_ABI);

export function wrapWithMulticall(updates) {
    // Convert individual updates to multicall format
    const calls = updates.map((update) => ({
        target: AGREEMENT_ADDRESS,
        callData: update.calldata,
    }));

    // Generate multicall calldata
    const multicallCalldata = multicallInterface.encodeFunctionData(
        "aggregate",
        [calls],
    );

    return {
        target: MULTICALL_ADDRESS,
        calldata: multicallCalldata,
    };
}
