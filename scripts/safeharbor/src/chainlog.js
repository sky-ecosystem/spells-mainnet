import { Contract, encodeBytes32String } from "ethers";
import { CHAINLOG_ABI } from "./abis.js";
import { CHAINLOG_ADDRESS } from "./constants.js";

export async function getChainlogAddress(provider, key) {
    const chainlogInstance = new Contract(
        CHAINLOG_ADDRESS,
        CHAINLOG_ABI,
        provider,
    );
    return chainlogInstance["getAddress(bytes32)"](encodeBytes32String(key));
}
