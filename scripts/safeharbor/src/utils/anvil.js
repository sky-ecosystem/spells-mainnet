import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { setTimeout as delay } from "node:timers/promises";

const MAX_LOG_LENGTH = 64 * 1024;
const STOP_TIMEOUT = 3_000;

/**
 * Rejects ports already owned by another TCP listener.
 */
export function assertPortAvailable(port) {
    return new Promise((resolvePromise, rejectPromise) => {
        const server = createServer();

        server.once("error", (error) => {
            if (error.code === "EADDRINUSE") {
                rejectPromise(new Error(`Port ${port} is already in use`));
                return;
            }
            rejectPromise(error);
        });

        server.listen({ host: "127.0.0.1", port, exclusive: true }, () => {
            server.close((error) => {
                if (error) rejectPromise(error);
                else resolvePromise();
            });
        });
    });
}

/**
 * Starts an Anvil mainnet fork that remains alive until explicit cleanup.
 */
export function startAnvil({ cwd, rpcUrl, forkBlock, port }) {
    const args = [
        "--fork-url",
        rpcUrl,
        "--chain-id",
        "1",
        "--hardfork",
        "cancun",
        "--host",
        "127.0.0.1",
        "--port",
        String(port),
        "--gas-limit",
        "1000000000",
    ];
    if (forkBlock !== undefined) {
        args.push("--fork-block-number", String(forkBlock));
    }

    const child = spawn("anvil", args, {
        cwd,
        env: process.env,
        stdio: ["ignore", "pipe", "pipe"],
    });

    let output = "";
    let listeningSettled = false;
    const listeningMessage = `Listening on 127.0.0.1:${port}`;

    const listening = new Promise((resolve, reject) => {
        function recordOutput(data) {
            output = appendLog(output, data);
            if (!listeningSettled && output.includes(listeningMessage)) {
                listeningSettled = true;
                resolve();
            }
        }

        child.stdout.on("data", recordOutput);
        child.stderr.on("data", recordOutput);

        child.once("error", (error) => {
            if (listeningSettled) {
                return;
            }
            listeningSettled = true;

            output = appendLog(output, error.message);
            reject(
                new Error(`Could not start Anvil:\n${output.trim()}`, {
                    cause: error,
                }),
            );
        });

        child.once("close", () => {
            if (listeningSettled) {
                return;
            }
            listeningSettled = true;

            reject(anvilExitError(output));
        });
    });

    const exited = new Promise((resolve) => {
        child.once("close", resolve);
    });

    return {
        child,
        listening,
        exited,
        getOutput: () => output.trim(),
    };
}

/**
 * Waits for Anvil to become available or times out after 30 seconds
 */
export async function waitForAnvil(anvil, rpcUrl, signal) {
    const startupTimeout = delay(30_000, undefined, {
        signal,
        ref: false,
    }).then(() => {
        throw new Error("Anvil did not become ready within 30 seconds");
    });

    await Promise.race([anvil.listening, startupTimeout]);

    const chainId = await Promise.race([
        requestRpc(rpcUrl, "eth_chainId", [], signal),
        anvil.exited.then(() => {
            throw anvilExitError(anvil.getOutput());
        }),
    ]);

    if (BigInt(chainId) !== 1n) {
        throw new Error("Anvil fork did not start with chain ID 1");
    }
}

/**
 * Stops Anvil gracefully and uses SIGKILL only if it does not exit in time.
 */
export async function stopAnvil(anvil, timeout = STOP_TIMEOUT) {
    const { child, exited } = anvil;
    if (child.exitCode !== null || child.signalCode !== null) return;

    child.kill("SIGTERM");
    if (await exitsWithin(exited, timeout)) return;

    if (child.exitCode === null && child.signalCode === null) {
        child.kill("SIGKILL");
    }

    if (!(await exitsWithin(exited, timeout))) {
        throw new Error("Anvil did not exit after SIGKILL");
    }
}

async function requestRpc(rpcUrl, method, params = [], signal) {
    const timeoutSignal = AbortSignal.timeout(1000);
    const requestSignal = signal
        ? AbortSignal.any([signal, timeoutSignal])
        : timeoutSignal;
    const response = await fetch(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
        signal: requestSignal,
    });
    const result = await response.json();

    if (!response.ok || result.error) {
        throw new Error(
            result.error?.message || `RPC request failed: ${method}`,
        );
    }
    return result.result;
}

function anvilExitError(output) {
    const details = output.trim();

    return new Error(
        `Anvil exited before becoming ready${details ? `:\n${details}` : ""}`,
    );
}

function appendLog(current, chunk) {
    return `${current}${chunk}`.slice(-MAX_LOG_LENGTH);
}

async function exitsWithin(exited, timeout) {
    return Promise.race([
        exited.then(() => true),
        delay(timeout, false, { ref: false }),
    ]);
}
