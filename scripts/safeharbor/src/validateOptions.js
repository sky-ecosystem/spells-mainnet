const COMMANDS = new Set(["generate", "inspect", "verify"]);

export function validateOptions({ command, rpcUrl }) {
    if (!command) return [{ code: "COMMAND_REQUIRED" }];
    if (!COMMANDS.has(command)) {
        return [{ code: "UNKNOWN_COMMAND", context: { command } }];
    }
    return rpcUrl ? [] : [{ code: "RPC_URL_REQUIRED" }];
}
