import { Contract, Interface, JsonRpcProvider } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AGREEMENT_V3_ABI } from "../src/agreement/abis.js";
import { main } from "../src/cli/index.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
    JsonRpcProvider: vi.fn(),
}));

let provider;
let argv;

beforeEach(() => {
    argv = process.argv;
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
        scenario: "inherited object property as command",
        argv: ["node", "index.js", "toString"],
        rpcUrl: "https://rpc.example",
        message:
            "Error: Unknown command 'toString'\nAvailable commands: generate, inspect, verify\nUsage: npm run <command>",
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

    expect(await main()).toBe(1);
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

    expect(await main()).toBe(0);
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

    expect(await main()).toBe(1);
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

    expect(await main()).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        "Failed to execute command:",
        "Invalid RPC configuration",
    );
    expect(fetch).not.toHaveBeenCalled();
});

test.each(["encoding", "reporting"])(
    "reports a %s failure once and destroys the provider",
    async (stage) => {
        process.argv = ["node", "index.js", "generate"];
        fetch
            .mockResolvedValueOnce(
                new Response(
                    "Name,Chain Id,Asset Recovery Address\nETH,eip155:1,0x1000000000000000000000000000000000000001\n",
                    { headers: { "content-type": "text/csv" } },
                ),
            )
            .mockResolvedValueOnce(
                new Response("Status,Chain,Address,isFactory\n", {
                    headers: { "content-type": "text/csv" },
                }),
            );
        Contract.mockReturnValueOnce({
            "getAddress(bytes32)": vi
                .fn()
                .mockResolvedValue(
                    "0x7000000000000000000000000000000000000001",
                ),
        }).mockReturnValueOnce({
            getDetails: vi.fn().mockResolvedValue({
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [
                            {
                                accountAddress:
                                    "0x2000000000000000000000000000000000000001",
                                childContractScope: 0n,
                            },
                        ],
                    },
                ],
            }),
        });
        const failure = new Error(`${stage} failed`);
        if (stage === "encoding") {
            vi.spyOn(
                Interface.prototype,
                "encodeFunctionData",
            ).mockImplementation(() => {
                throw failure;
            });
        } else {
            console.log.mockImplementation(() => {
                throw failure;
            });
        }

        expect(await main()).toBe(1);
        expect(console.error).toHaveBeenCalledExactlyOnceWith(
            "Failed to execute command:",
            `${stage} failed`,
        );
        expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
    },
);
