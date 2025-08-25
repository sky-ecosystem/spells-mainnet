import { Interface } from "ethers";
import { MULTICALL_ABI } from "../abis.js";

const multicallInterface = new Interface(MULTICALL_ABI);

export function wrapWithMulticall(
    updates,
    agreementContractAddress,
    multicallContractAddress,
    inspect = false,
) {
    // If no updates, return the original array
    if (updates.length === 0) {
        return updates;
    }

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
    let multicallUpdate;

    // Add the multicall update to the array
    if (inspect) {
        multicallUpdate = {
            function: "multicall",
            args: updates,
            calldata: multicallCalldata,
            target: multicallContractAddress,
        };
    } else {
        multicallUpdate = {
            target: multicallContractAddress,
            calldata: multicallCalldata,
        };
    }

    // Return original updates plus the multicall wrapper
    return multicallUpdate;
}
