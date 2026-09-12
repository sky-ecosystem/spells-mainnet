import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { COMMANDS } from "./commands/index.js";

export function validateOptions({ command, rpcUrl }) {
    if (!command) {
        return [{ code: $.COMMAND_REQUIRED }];
    }
    if (!Object.hasOwn(COMMANDS, command)) {
        return [{ code: $.UNKNOWN_COMMAND, context: { command } }];
    }
    return rpcUrl ? [] : [{ code: $.RPC_URL_REQUIRED }];
}
