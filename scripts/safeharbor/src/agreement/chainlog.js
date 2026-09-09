import { Contract, encodeBytes32String } from "ethers";
// Verified ABI: https://etherscan.io/address/0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F#code
import CHAINLOG_ABI from "./abis/chainlog.json" with { type: "json" };

export const CHAINLOG_ADDRESS = "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F";

export async function getChainlogAddress(provider, key) {
    const chainlogInstance = new Contract(
        CHAINLOG_ADDRESS,
        CHAINLOG_ABI,
        provider,
    );
    return chainlogInstance["getAddress(bytes32)"](encodeBytes32String(key));
}
