import { encodeUpdates } from "../agreement/index.js";
import { generateSolidity } from "./solidity.js";

export function generatePayload(changes) {
    const updates = encodeUpdates(changes);
    return { updates, solidityCode: generateSolidity(updates) };
}
