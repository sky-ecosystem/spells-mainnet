import { Contract, JsonRpcProvider } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AGREEMENT_V3_ABI } from "../src/abis.js";

vi.mock("dotenv/config", () => ({}));
vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
    JsonRpcProvider: vi.fn(),
}));

let provider;
let argv;
let exitCode;

beforeEach(() => {
    vi.resetModules();
    argv = process.argv;
    exitCode = process.exitCode;
    process.argv = ["node", "index.js", "verify"];
    vi.stubEnv("ETH_RPC_URL", "https://rpc.example");
    vi.stubGlobal("fetch", vi.fn());
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(console, "error").mockImplementation(() => {});
    provider = { destroy: vi.fn() };
    JsonRpcProvider.mockReturnValue(provider);
});

afterEach(() => {
    process.argv = argv;
    process.exitCode = exitCode;
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetAllMocks();
    vi.restoreAllMocks();
});

test.each([
    {
        scenario: "missing command before missing RPC configuration",
        argv: ["node", "index.js"],
        rpcUrl: "",
        message:
            "Error: Command is required\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    },
    {
        scenario: "unknown command before missing RPC configuration",
        argv: ["node", "index.js", "unknown"],
        rpcUrl: "",
        message:
            "Error: Unknown command 'unknown'\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
    },
    {
        scenario: "missing RPC configuration",
        argv: ["node", "index.js", "verify"],
        rpcUrl: "",
        message:
            "Error: ETH_RPC_URL environment variable is not set.\nPlease set your Ethereum RPC URL in a .env file or as an environment variable.\nExample: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY",
    },
])("rejects $scenario before constructing dependencies", async (fixture) => {
    process.argv = fixture.argv;
    vi.stubEnv("ETH_RPC_URL", fixture.rpcUrl);

    await import("../index.js");

    expect(process.exitCode).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(fixture.message);
    expect(console.log).not.toHaveBeenCalled();
    expect(JsonRpcProvider).not.toHaveBeenCalled();
    expect(Contract).not.toHaveBeenCalled();
    expect(fetch).not.toHaveBeenCalled();
});

test("wires the provider through the real pipeline and destroys it after success", async () => {
    fetch
        .mockResolvedValueOnce(
            new Response("Name,Chain Id,Asset Recovery Address\n", {
                headers: { "content-type": "text/csv" },
            }),
        )
        .mockResolvedValueOnce(
            new Response("Status,Chain,Address,isFactory\n", {
                headers: { "content-type": "text/csv" },
            }),
        );
    const getDetails = vi.fn().mockResolvedValue({ chains: [] });
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi
            .fn()
            .mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });

    await import("../index.js");

    expect(process.exitCode).toBe(0);
    expect(JsonRpcProvider).toHaveBeenCalledExactlyOnceWith(
        "https://rpc.example",
    );
    expect(Contract).toHaveBeenLastCalledWith(
        "0x7000000000000000000000000000000000000001",
        AGREEMENT_V3_ABI,
        provider,
    );
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    expect(console.log).toHaveBeenCalledExactlyOnceWith(
        "SafeHarbor verification passed: no updates or validation warnings.",
    );
    expect(console.error).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("destroys the provider after a pipeline failure", async () => {
    const failure = new Error("CSV unavailable");
    fetch.mockRejectedValue(failure);

    await import("../index.js");

    expect(process.exitCode).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        "Failed to execute command:",
        "CSV unavailable",
    );
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("reports provider construction failures as command errors", async () => {
    const failure = new Error("Invalid RPC configuration");
    JsonRpcProvider.mockImplementation(() => {
        throw failure;
    });

    await import("../index.js");

    expect(process.exitCode).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        "Failed to execute command:",
        "Invalid RPC configuration",
    );
    expect(fetch).not.toHaveBeenCalled();
});
