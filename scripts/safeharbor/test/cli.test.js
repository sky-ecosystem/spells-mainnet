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
        rpcUrl: "https://rpc.example",
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
