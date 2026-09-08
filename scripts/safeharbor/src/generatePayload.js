import { encodeUpdates } from "./agreement.js";
import { generateSolidityCode } from "./generateSolidity.js";

export function generatePayload(changes) {
    const updates = encodeUpdates(changes);
    return { updates, solidityCode: generateSolidityCode(updates) };
}
