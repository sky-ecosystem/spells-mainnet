import { expect, test } from "vitest";
import { validateOptions } from "./validateOptions.js";

test.each([
    {
        options: { command: undefined, rpcUrl: "" },
        diagnostics: [{ code: "COMMAND_REQUIRED" }],
    },
    {
        options: { command: "unknown", rpcUrl: "" },
        diagnostics: [
            { code: "UNKNOWN_COMMAND", context: { command: "unknown" } },
        ],
    },
    {
        options: { command: "verify", rpcUrl: "" },
        diagnostics: [{ code: "RPC_URL_REQUIRED" }],
    },
    {
        options: { command: "verify", rpcUrl: "https://rpc.example" },
        diagnostics: [],
    },
    {
        options: { command: "generate", rpcUrl: "https://rpc.example" },
        diagnostics: [],
    },
    {
        options: { command: "inspect", rpcUrl: "https://rpc.example" },
        diagnostics: [],
    },
])("validates $options without formatting", ({ options, diagnostics }) => {
    expect(validateOptions(options)).toEqual(diagnostics);
});
