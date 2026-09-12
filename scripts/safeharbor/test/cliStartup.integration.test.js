import { Contract, Interface, JsonRpcProvider } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { dedent } from "../src/utils/dedent.js";
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
        message: dedent`
            ❌ Error: Command is required
                   Available commands: generate, inspect, verify
                   Usage: npm run <command>
        `,
    },
    {
        scenario: "unknown command before missing RPC configuration",
        argv: ["node", "index.js", "unknown"],
        rpcUrl: "",
        message: dedent`
            ❌ Error: Unknown command 'unknown'
                   Available commands: generate, inspect, verify
                   Usage: npm run <command>
        `,
    },
    {
        scenario: "inherited object property as command",
        argv: ["node", "index.js", "toString"],
        rpcUrl: "https://rpc.example",
        message: dedent`
            ❌ Error: Unknown command 'toString'
                   Available commands: generate, inspect, verify
                   Usage: npm run <command>
        `,
    },
    {
        scenario: "missing RPC configuration",
        argv: ["node", "index.js", "verify"],
        rpcUrl: "",
        message: dedent`
            ❌ Error: ETH_RPC_URL environment variable is not set.
                   Please set your Ethereum RPC URL in a .env file or as an environment variable.
                   Example: ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
        `,
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
        "getAddress(bytes32)": vi.fn().mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });

    expect(await main()).toBe(0);
    expect(JsonRpcProvider).toHaveBeenCalledExactlyOnceWith("https://rpc.example");
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    expect(console.log).toHaveBeenCalledExactlyOnceWith(
        "✅ SafeHarbor verification passed: no updates or validation warnings.",
    );
    expect(console.error).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("indents multiline pipeline errors and nested codes without displaying the source wrapper as a cause", async () => {
    const failure = Object.assign(
        new Error(
            dedent`
                CSV unavailable
                Connection closed
            `,
            {
                cause: Object.assign(
                    new AggregateError(
                        [new Error("private AggregateError member")],
                        "Request to https://rpc.example/private-key failed",
                        {
                            cause: Object.assign(new Error("private connection details"), { code: "ECONNREFUSED" }),
                        },
                    ),
                    { code: "NETWORK_ERROR" },
                ),
            },
        ),
        { code: "FETCH_FAILED" },
    );
    fetch.mockRejectedValue(failure);

    expect(await main()).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        dedent`
            ❌ Failed to execute command:
                   Source: Safeharbor Sheet chain metadata
                   CSV unavailable
                   Connection closed
                   Code: FETCH_FAILED
                       Cause: NETWORK_ERROR
                           Cause: ECONNREFUSED
        `,
    );
    expect(console.log).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("reports a Sheet failure and destroys the provider without starting an Agreement read", async () => {
    fetch
        .mockResolvedValueOnce(
            new Response("Name,Chain Id,Asset Recovery Address\n", {
                headers: { "content-type": "text/csv" },
            }),
        )
        .mockRejectedValueOnce(new Error("Contracts unavailable"));
    const getChainlogAddress = vi.fn();
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": getChainlogAddress,
    });

    expect(await main()).toBe(1);
    expect(getChainlogAddress).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        dedent`
            ❌ Failed to execute command:
                   Source: Safeharbor Sheet contracts
                   Contracts unavailable
        `,
    );
    expect(console.log).not.toHaveBeenCalled();
});

test("reports provider construction failures as command errors", async () => {
    const failure = Object.assign(new Error("Invalid RPC configuration"), {
        code: "INVALID_ARGUMENT",
    });
    JsonRpcProvider.mockImplementation(() => {
        throw failure;
    });

    expect(await main()).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        dedent`
            ❌ Failed to execute command:
                   Invalid RPC configuration
                   Code: INVALID_ARGUMENT
        `,
    );
    expect(fetch).not.toHaveBeenCalled();
});

test("reports Chainlog construction failures and destroys the provider", async () => {
    Contract.mockImplementation(() => {
        throw new Error("Chainlog construction failed");
    });

    expect(await main()).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        dedent`
            ❌ Failed to execute command:
                   Chainlog construction failed
        `,
    );
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
    expect(fetch).not.toHaveBeenCalled();
});

test.each(["encoding", "reporting"])("reports a %s failure once and destroys the provider", async (stage) => {
    process.argv = ["node", "index.js", "generate"];
    fetch
        .mockResolvedValueOnce(
            new Response(
                dedent`
                        Name,Chain Id,Asset Recovery Address
                        ETH,eip155:1,0x1000000000000000000000000000000000000001
                    `,
                { headers: { "content-type": "text/csv" } },
            ),
        )
        .mockResolvedValueOnce(
            new Response("Status,Chain,Address,isFactory\n", {
                headers: { "content-type": "text/csv" },
            }),
        );
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi.fn().mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({
        getDetails: vi.fn().mockResolvedValue({
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        }),
    });
    const failure = new Error(`${stage} failed`);
    if (stage === "encoding") {
        vi.spyOn(Interface.prototype, "encodeFunctionData").mockImplementation(() => {
            throw failure;
        });
    } else {
        console.log.mockImplementation(() => {
            throw failure;
        });
    }

    expect(await main()).toBe(1);
    expect(console.error).toHaveBeenCalledExactlyOnceWith(
        dedent`
                ❌ Failed to execute command:
                       ${stage} failed
            `,
    );
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});
