import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { runCommand } from "../src/cli.js";
import { generatePayload } from "../src/generatePayload.js";
import { createAgreementInstance } from "../src/utils/contractUtils.js";

vi.mock("../src/generatePayload.js", () => ({ generatePayload: vi.fn() }));
vi.mock("../src/utils/contractUtils.js", () => ({
    createAgreementInstance: vi.fn(),
}));

const CLEAN_RESULT = {
    updates: [],
    solidityCode: "",
    validationWarnings: [],
};
const agreementContract = {};

let stdout;
let stderr;

beforeEach(() => {
    vi.stubEnv("ETH_RPC_URL", "https://rpc.example");
    createAgreementInstance.mockResolvedValue(agreementContract);
    generatePayload.mockResolvedValue(CLEAN_RESULT);
    stdout = vi.spyOn(console, "log").mockImplementation(() => {});
    stderr = vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
});

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
        generatePayload.mockResolvedValue(result);

        const exitCode = await runCommand("generate");

        expect(exitCode).toBe(0);
        if (expectedOutput) {
            expect(stdout).toHaveBeenCalledWith(expectedOutput);
        } else {
            expect(stdout).not.toHaveBeenCalled();
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
            generatePayload.mockResolvedValue(result);

            const exitCode = await runCommand("inspect");

            expect(exitCode).toBe(0);
            expect(stdout).toHaveBeenCalledWith(
                JSON.stringify(result, null, 2),
            );
        },
    );

    test("verify exits 0 when no updates or warnings are found", async () => {
        const exitCode = await runCommand("verify");

        expect(exitCode).toBe(0);
        expect(stdout).toHaveBeenCalledWith(
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
        generatePayload.mockResolvedValue({
            updates,
            solidityCode: updates.length > 0 ? "generated solidity" : "",
            validationWarnings: warnings,
        });

        const exitCode = await runCommand("verify");

        expect(exitCode).toBe(2);
        expect(stdout).toHaveBeenCalledWith(
            `SafeHarbor verification failed: ${updates.length} update(s), ${warnings.length} validation warning(s).`,
        );
    });

    test("defaults to generate when no command is provided", async () => {
        const exitCode = await runCommand();

        expect(exitCode).toBe(0);
        expect(generatePayload).toHaveBeenCalledWith(agreementContract);
    });

    test("exits 1 for an unknown command", async () => {
        const exitCode = await runCommand("unknown");

        expect(exitCode).toBe(1);
        expect(stderr).toHaveBeenCalledWith("Error: Unknown command 'unknown'");
        expect(createAgreementInstance).not.toHaveBeenCalled();
    });

    test("exits 1 when ETH_RPC_URL is missing", async () => {
        vi.stubEnv("ETH_RPC_URL", "");

        const exitCode = await runCommand("verify");

        expect(exitCode).toBe(1);
        expect(stderr).toHaveBeenCalledWith(
            "Error: ETH_RPC_URL environment variable is not set.",
        );
        expect(createAgreementInstance).not.toHaveBeenCalled();
    });

    test("exits 1 when payload generation fails", async () => {
        const failure = new Error("RPC unavailable");
        generatePayload.mockRejectedValue(failure);

        const exitCode = await runCommand("inspect");

        expect(exitCode).toBe(1);
        expect(stderr).toHaveBeenCalledWith(
            "Failed to execute command:",
            failure,
        );
    });
});
