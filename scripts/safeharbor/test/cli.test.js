import { describe, expect, test, vi } from "vitest";
import { runCommand } from "../src/cli.js";

const CLEAN_RESULT = {
    updates: [],
    solidityCode: "",
    validationWarnings: [],
};

function commandContext(result = CLEAN_RESULT) {
    const agreementContract = {};
    return {
        agreementContract,
        createAgreement: vi.fn().mockResolvedValue(agreementContract),
        generate: vi.fn().mockResolvedValue(result),
        testSpell: vi.fn().mockResolvedValue(0),
        rpcUrl: "https://rpc.example",
        forkBlock: "25847641",
        port: "18545",
        stdout: vi.fn(),
        stderr: vi.fn(),
        warn: vi.fn(),
    };
}

describe("runCommand", () => {
    test.each([
        [
            "with updates",
            {
                updates: [{ function: "addAccounts" }],
                solidityCode: "generated solidity",
                validationWarnings: [],
            },
            "generated solidity",
        ],
        ["without updates", CLEAN_RESULT, undefined],
    ])("generate exits 0 %s", async (_scenario, result, expectedOutput) => {
        const context = commandContext(result);

        const exitCode = await runCommand("generate", context);

        expect(exitCode).toBe(0);
        if (expectedOutput) {
            expect(context.stdout).toHaveBeenCalledWith(expectedOutput);
        } else {
            expect(context.stdout).not.toHaveBeenCalled();
        }
    });

    test.each([
        ["without differences", CLEAN_RESULT],
        [
            "with updates and warnings",
            {
                updates: [{ function: "addAccounts" }],
                solidityCode: "generated solidity",
                validationWarnings: ["recovery address mismatch"],
            },
        ],
    ])(
        "inspect prints complete JSON and exits 0 %s",
        async (_scenario, result) => {
            const context = commandContext(result);

            const exitCode = await runCommand("inspect", context);

            expect(exitCode).toBe(0);
            expect(context.stdout).toHaveBeenCalledWith(
                JSON.stringify(result, null, 2),
            );
        },
    );

    test("verify exits 0 when no updates or warnings are found", async () => {
        const context = commandContext();

        const exitCode = await runCommand("verify", context);

        expect(exitCode).toBe(0);
        expect(context.stdout).toHaveBeenCalledWith(
            "SafeHarbor verification passed: no updates or validation warnings.",
        );
    });

    test.each([
        ["updates", [{ function: "addAccounts" }], []],
        ["warnings", [], ["recovery address mismatch"]],
        [
            "updates and warnings",
            [{ function: "addAccounts" }],
            ["recovery address mismatch"],
        ],
    ])("verify exits 2 for %s", async (_scenario, updates, warnings) => {
        const context = commandContext({
            updates,
            solidityCode: updates.length > 0 ? "generated solidity" : "",
            validationWarnings: warnings,
        });

        const exitCode = await runCommand("verify", context);

        expect(exitCode).toBe(2);
        expect(context.stdout).toHaveBeenCalledWith(
            `SafeHarbor verification failed: ${updates.length} update(s), ${warnings.length} validation warning(s).`,
        );
    });

    test("routes testSpell with its command context", async () => {
        const context = commandContext();

        const exitCode = await runCommand("testSpell", context);

        expect(exitCode).toBe(0);
        expect(context.testSpell).toHaveBeenCalledWith({
            rpcUrl: context.rpcUrl,
            forkBlock: context.forkBlock,
            port: context.port,
            verify: expect.any(Function),
        });
        expect(context.createAgreement).not.toHaveBeenCalled();
        expect(context.generate).not.toHaveBeenCalled();
    });

    test("testSpell preserves verification status 2", async () => {
        const context = commandContext({
            updates: [],
            solidityCode: "",
            validationWarnings: ["recovery address mismatch"],
        });
        context.testSpell.mockImplementation(({ verify }) =>
            verify("http://127.0.0.1:18545"),
        );

        const exitCode = await runCommand("testSpell", context);

        expect(exitCode).toBe(2);
        expect(context.createAgreement).toHaveBeenCalledWith(
            "http://127.0.0.1:18545",
        );
    });

    test("testSpell exits 1 for an operational failure", async () => {
        const context = commandContext();
        const failure = new Error("Anvil failed to start");
        context.testSpell.mockRejectedValue(failure);

        const exitCode = await runCommand("testSpell", context);

        expect(exitCode).toBe(1);
        expect(context.stderr).toHaveBeenCalledWith(
            "Failed to execute command:",
            failure,
        );
    });

    test.each([
        ["forkBlock", "invalid", "SAFEHARBOR_FORK_BLOCK"],
        ["port", "0", "ANVIL_PORT"],
    ])("testSpell exits 1 for invalid %s", async (field, value, name) => {
        const context = commandContext();
        delete context.testSpell;
        context[field] = value;

        const exitCode = await runCommand("testSpell", context);

        expect(exitCode).toBe(1);
        expect(context.stderr).toHaveBeenCalledWith(
            "Failed to execute command:",
            expect.objectContaining({ message: expect.stringContaining(name) }),
        );
    });

    test.each([
        ["SIGINT", 130],
        ["SIGTERM", 143],
    ])("testSpell preserves %s cleanup status", async (signal, exitCode) => {
        const context = commandContext();
        const cleanup = vi.fn();
        const interruption = Object.assign(
            new Error(`Interrupted by ${signal}`),
            { interrupted: true, exitCode },
        );
        context.testSpell.mockImplementation(async () => {
            try {
                throw interruption;
            } finally {
                cleanup();
            }
        });

        expect(await runCommand("testSpell", context)).toBe(exitCode);
        expect(cleanup).toHaveBeenCalledOnce();
        expect(context.stderr).not.toHaveBeenCalled();
    });

    test("defaults to generate when no command is provided", async () => {
        const context = commandContext();

        const exitCode = await runCommand(undefined, context);

        expect(exitCode).toBe(0);
        expect(context.generate).toHaveBeenCalledWith(
            context.agreementContract,
        );
    });

    test("exits 1 for an unknown command", async () => {
        const context = commandContext();

        const exitCode = await runCommand("unknown", context);

        expect(exitCode).toBe(1);
        expect(context.stderr).toHaveBeenCalledWith(
            "Error: Unknown command 'unknown'",
        );
        expect(context.createAgreement).not.toHaveBeenCalled();
    });

    test("exits 1 when ETH_RPC_URL is missing", async () => {
        const context = commandContext();
        context.rpcUrl = undefined;

        const exitCode = await runCommand("verify", context);

        expect(exitCode).toBe(1);
        expect(context.stderr).toHaveBeenCalledWith(
            "Error: ETH_RPC_URL environment variable is not set.",
        );
        expect(context.createAgreement).not.toHaveBeenCalled();
    });

    test("exits 1 when payload generation fails", async () => {
        const context = commandContext();
        const failure = new Error("RPC unavailable");
        context.generate.mockRejectedValue(failure);

        const exitCode = await runCommand("inspect", context);

        expect(exitCode).toBe(1);
        expect(context.stderr).toHaveBeenCalledWith(
            "Failed to execute command:",
            failure,
        );
    });
});
