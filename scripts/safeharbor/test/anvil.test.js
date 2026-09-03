import { createServer } from "node:net";
import { afterEach, describe, expect, test, vi } from "vitest";
import {
    assertPortAvailable,
    stopAnvil,
    waitForAnvil,
} from "../src/utils/anvil.js";

afterEach(() => {
    vi.unstubAllGlobals();
});

describe("Anvil lifecycle", () => {
    test("rejects a port already owned by another listener", async () => {
        const server = createServer();
        await listen(server);
        const { port } = server.address();

        try {
            await expect(assertPortAvailable(port)).rejects.toThrow(
                `Port ${port} is already in use`,
            );
        } finally {
            await close(server);
        }
    });

    test("accepts a free port", async () => {
        const server = createServer();
        await listen(server);
        const { port } = server.address();
        await close(server);

        await expect(assertPortAvailable(port)).resolves.toBeUndefined();
    });

    test("does not query RPC before the launched child is listening", async () => {
        const listening = deferred();
        const exited = deferred();
        const fetchMock = vi.fn().mockResolvedValue(rpcResponse("0x1"));
        vi.stubGlobal("fetch", fetchMock);
        const anvil = {
            listening: listening.promise,
            exited: exited.promise,
            getOutput: () => "",
        };

        const ready = waitForAnvil(
            anvil,
            "http://127.0.0.1:18545",
            new AbortController().signal,
        );
        await Promise.resolve();
        expect(fetchMock).not.toHaveBeenCalled();

        listening.resolve();
        await ready;
        expect(fetchMock).toHaveBeenCalledOnce();
    });

    test("rejects when the launched child exits during the RPC check", async () => {
        const request = deferred();
        const exited = deferred();
        vi.stubGlobal(
            "fetch",
            vi.fn(() => request.promise),
        );
        const anvil = {
            listening: Promise.resolve(),
            exited: exited.promise,
            getOutput: () => "bind failed",
        };

        const ready = waitForAnvil(
            anvil,
            "http://127.0.0.1:18545",
            new AbortController().signal,
        );
        await vi.waitFor(() => expect(fetch).toHaveBeenCalledOnce());
        exited.resolve();

        await expect(ready).rejects.toThrow(
            "Anvil exited before becoming ready:\nbind failed",
        );
    });

    test("rejects a fork with the wrong chain ID", async () => {
        vi.stubGlobal("fetch", vi.fn().mockResolvedValue(rpcResponse("0x2")));
        const anvil = {
            listening: Promise.resolve(),
            exited: new Promise(() => {}),
            getOutput: () => "",
        };

        await expect(
            waitForAnvil(
                anvil,
                "http://127.0.0.1:18545",
                new AbortController().signal,
            ),
        ).rejects.toThrow("Anvil fork did not start with chain ID 1");
    });

    test("stops Anvil with SIGTERM when it exits promptly", async () => {
        const exited = deferred();
        const child = runningChild((signal) => {
            if (signal === "SIGTERM") exited.resolve();
        });

        await stopAnvil({ child, exited: exited.promise }, 10);

        expect(child.kill).toHaveBeenCalledOnce();
        expect(child.kill).toHaveBeenCalledWith("SIGTERM");
    });

    test("uses SIGKILL when Anvil ignores SIGTERM", async () => {
        const exited = deferred();
        const child = runningChild((signal) => {
            if (signal === "SIGKILL") exited.resolve();
        });

        await stopAnvil({ child, exited: exited.promise }, 10);

        expect(child.kill.mock.calls).toEqual([["SIGTERM"], ["SIGKILL"]]);
    });

    test("fails instead of hanging when Anvil ignores SIGKILL", async () => {
        const child = runningChild();

        await expect(
            stopAnvil({ child, exited: new Promise(() => {}) }, 10),
        ).rejects.toThrow("Anvil did not exit after SIGKILL");
        expect(child.kill.mock.calls).toEqual([["SIGTERM"], ["SIGKILL"]]);
    });
});

function deferred() {
    let resolve;
    const promise = new Promise((resolvePromise) => {
        resolve = resolvePromise;
    });
    return { promise, resolve };
}

function rpcResponse(chainId) {
    return {
        ok: true,
        json: vi.fn().mockResolvedValue({ result: chainId }),
    };
}

function runningChild(onKill = () => {}) {
    return {
        exitCode: null,
        signalCode: null,
        kill: vi.fn(onKill),
    };
}

function listen(server) {
    return new Promise((resolvePromise, rejectPromise) => {
        server.once("error", rejectPromise);
        server.listen(0, "127.0.0.1", resolvePromise);
    });
}

function close(server) {
    return new Promise((resolvePromise, rejectPromise) => {
        server.close((error) => {
            if (error) rejectPromise(error);
            else resolvePromise();
        });
    });
}
