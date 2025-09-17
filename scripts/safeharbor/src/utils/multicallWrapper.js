import { Interface } from "ethers";
import { MULTICALL_ABI } from "../abis.js";

const multicallInterface = new Interface(MULTICALL_ABI);

/**
 * Wraps a list of contract update calldata entries into a single multicall payload.
 *
 * @param {Array<{calldata: string}>} updates - Array of update objects; each must include a `calldata` string for the target agreement contract.
 * @param {string} agreementContractAddress - Address of the agreement contract to be called for each update.
 * @param {string} multicallContractAddress - Address of the multicall contract that will execute the aggregated calls.
 * @return {{target: string, calldata: string}} An object suitable for sending as a single transaction: `target` is the multicall contract address and `calldata` is the encoded `aggregate` call containing all individual calls.
 */
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
