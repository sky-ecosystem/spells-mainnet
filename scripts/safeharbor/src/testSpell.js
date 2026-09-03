import { spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
    Contract,
    JsonRpcProvider,
    encodeBytes32String,
    getAddress,
    toQuantity,
    zeroPadValue,
} from "ethers";
import { CHAINLOG_ABI } from "./abis.js";
import { CHAINLOG_ADDRESS } from "./constants.js";
import {
    assertPortAvailable,
    startAnvil,
    stopAnvil,
    waitForAnvil,
} from "./utils/anvil.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_ANVIL_PORT = 8545;
const ANVIL_SENDER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const CHIEF_CHAINLOG_KEY = "MCD_ADM";
const CHIEF_HAT_SLOT =
    "0x0000000000000000000000000000000000000000000000000000000000000001";

const CHIEF_ABI = ["function hat() view returns (address)"];
const SPELL_ABI = [
    "function schedule()",
    "function nextCastTime() view returns (uint256)",
    "function cast()",
    "function done() view returns (bool)",
];

/**
 * Runs the SafeHarbor spell preflight and handles process interruption.
 */
export async function testSpell({ rpcUrl, forkBlock, port, verify } = {}) {
    // Handle SIGINT and SIGTERM to gracefully close the
    // anvil instance launched by the command
    const abortController = new AbortController();
    let interrupt;
    const handleSigint = () => {
        interrupt = new InterruptError("SIGINT");
        abortController.abort(interrupt);
    };
    const handleSigterm = () => {
        interrupt = new InterruptError("SIGTERM");
        abortController.abort(interrupt);
    };

    process.on("SIGINT", handleSigint);
    process.on("SIGTERM", handleSigterm);

    try {
        const exitCode = await runTestSpell({
            rpcUrl,
            forkBlock,
            port,
            verify,
            signal: abortController.signal,
        });
        if (interrupt) throw interrupt;
        return exitCode;
    } catch (error) {
        if (interrupt) throw interrupt;
        throw error;
    } finally {
        process.removeListener("SIGINT", handleSigint);
        process.removeListener("SIGTERM", handleSigterm);
    }
}

/**
 * Deploys and casts the local spell on an Anvil fork, then verifies SafeHarbor state.
 */
async function runTestSpell({ rpcUrl, forkBlock, port, verify, signal }) {
    const parsedForkBlock = parsePositiveInteger(
        forkBlock,
        "SAFEHARBOR_FORK_BLOCK",
        undefined,
        Number.MAX_SAFE_INTEGER,
    );
    const parsedPort = parsePositiveInteger(
        port,
        "ANVIL_PORT",
        DEFAULT_ANVIL_PORT,
        65535,
    );
    const localRpcUrl = `http://127.0.0.1:${parsedPort}`;

    if (typeof verify !== "function") {
        throw new TypeError("verify function was not provided");
    }

    await assertMainnetRpc(rpcUrl);
    signal.throwIfAborted();
    await assertPortAvailable(parsedPort);
    signal.throwIfAborted();

    console.log(`Starting Anvil fork at ${localRpcUrl}...`);
    const anvil = startAnvil({
        cwd: REPO_ROOT,
        rpcUrl,
        forkBlock: parsedForkBlock,
        port: parsedPort,
    });
    let provider;

    try {
        await waitForAnvil(anvil, localRpcUrl, signal);
        signal.throwIfAborted();
        provider = new JsonRpcProvider(localRpcUrl);

        const actualForkBlock = await provider.getBlockNumber();
        const { stdout: commit } = await runProcess(
            "git",
            ["rev-parse", "HEAD"],
            { signal },
        );
        console.log(`Commit: ${commit.trim()}`);
        console.log(`Fork block: ${actualForkBlock}`);

        const spellAddress = await deploySpell(localRpcUrl, signal);
        signal.throwIfAborted();
        console.log(`Local spell: ${spellAddress}`);
        await authorizeAndCast(provider, spellAddress);
        signal.throwIfAborted();

        console.log("Checking SafeHarbor state...");
        const verificationStatus = await verify(localRpcUrl);
        signal.throwIfAborted();
        if (verificationStatus !== 0) {
            return verificationStatus;
        }

        console.log("SafeHarbor spell preflight passed");
        return 0;
    } finally {
        provider?.destroy();
        await stopAnvil(anvil);
    }
}

async function assertMainnetRpc(rpcUrl) {
    if (!rpcUrl) {
        throw new Error("ETH_RPC_URL must point to Ethereum mainnet");
    }

    const provider = new JsonRpcProvider(rpcUrl);
    try {
        const network = await provider.getNetwork();
        if (network.chainId !== 1n) {
            throw new Error("ETH_RPC_URL must point to Ethereum mainnet");
        }
    } finally {
        provider.destroy();
    }
}

async function deploySpell(rpcUrl, signal) {
    console.log("Deploying local DssSpell...");
    const { stdout } = await runProcess(
        "forge",
        [
            "create",
            "--no-cache",
            "--broadcast",
            "--json",
            "--unlocked",
            "--from",
            ANVIL_SENDER,
            "--rpc-url",
            rpcUrl,
            "src/DssSpell.sol:DssSpell",
        ],
        { signal },
    );

    let deployment;
    try {
        deployment = JSON.parse(stdout);
    } catch {
        throw new Error(`Could not parse forge deployment output:\n${stdout}`);
    }

    try {
        return getAddress(deployment.deployedTo);
    } catch {
        throw new Error("Could not read deployed spell address");
    }
}

async function authorizeAndCast(provider, spellAddress) {
    const chainlog = new Contract(CHAINLOG_ADDRESS, CHAINLOG_ABI, provider);
    const chiefAddress = await chainlog["getAddress(bytes32)"](
        encodeBytes32String(CHIEF_CHAINLOG_KEY),
    );

    console.log("Giving local spell the Chief hat...");
    await provider.send("anvil_setStorageAt", [
        chiefAddress,
        CHIEF_HAT_SLOT,
        zeroPadValue(spellAddress, 32),
    ]);

    const chief = new Contract(chiefAddress, CHIEF_ABI, provider);
    if (getAddress(await chief.hat()) !== spellAddress) {
        throw new Error("Local spell did not receive the Chief hat");
    }

    const signer = await provider.getSigner(ANVIL_SENDER);
    const spell = new Contract(spellAddress, SPELL_ABI, signer);

    console.log("Scheduling local spell...");
    await (await spell.schedule({ gasLimit: 100000000n })).wait();

    const nextCastTime = await spell.nextCastTime();
    console.log(`Warping to ${nextCastTime} and casting local spell...`);
    await provider.send("evm_setNextBlockTimestamp", [
        toQuantity(nextCastTime),
    ]);
    await (await spell.cast({ gasLimit: 900000000n })).wait();

    if (!(await spell.done())) {
        throw new Error("Local spell cast did not complete");
    }
}

/**
 * Runs a child process and captures its output for parsing or error reporting.
 */
function runProcess(command, args, { cwd = REPO_ROOT, signal } = {}) {
    return new Promise((resolvePromise, rejectPromise) => {
        const child = spawn(command, args, {
            cwd,
            env: process.env,
            signal,
            stdio: ["ignore", "pipe", "pipe"],
        });
        let stdout = "";
        let stderr = "";
        let settled = false;

        child.stdout.on("data", (data) => {
            stdout += data;
        });
        child.stderr.on("data", (data) => {
            stderr += data;
        });

        child.once("error", (error) => {
            if (settled) return;
            settled = true;
            rejectPromise(error);
        });
        child.once("close", (code) => {
            if (settled) return;
            settled = true;
            if (code === 0) {
                resolvePromise({ stdout, stderr });
                return;
            }

            const output = stderr.trim() || stdout.trim();
            rejectPromise(
                new Error(
                    `${command} exited with status ${code}${output ? `:\n${output}` : ""}`,
                ),
            );
        });
    });
}

class InterruptError extends Error {
    constructor(signal) {
        super(`Interrupted by ${signal}`);
        this.interrupted = true;
        this.exitCode = signal === "SIGINT" ? 130 : 143;
    }
}

function parsePositiveInteger(value, name, fallback, maximum) {
    if (value === undefined || value === "") return fallback;
    if (!/^\d+$/.test(value)) {
        throw new Error(`${name} must be a positive integer`);
    }

    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > maximum) {
        throw new Error(`${name} must be between 1 and ${maximum}`);
    }
    return parsed;
}
