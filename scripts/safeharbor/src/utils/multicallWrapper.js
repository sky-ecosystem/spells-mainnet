import { Interface } from "ethers";
import { MULTICALL_ABI } from "../abis.js";

const multicallInterface = new Interface(MULTICALL_ABI);

export function wrapWithMulticall(
    updates,
    agreementContractAddress,
    multicallContractAddress,
) {
    // Convert individual updates to multicall format
    const calls = updates.map((update) => ({
        target: agreementContractAddress,
        callData: update.calldata,
    }));

    // Generate multicall calldata
    const multicallCalldata = multicallInterface.encodeFunctionData(
        "aggregate",
        [calls],
    );

    return {
        target: multicallContractAddress,
        calldata: multicallCalldata,
    };
}
