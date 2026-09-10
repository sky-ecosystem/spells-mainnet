import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { generatePayload } from "../../generation/index.js";
import { verify } from "./verify.js";

vi.mock("../../generation/index.js", () => ({
    generatePayload: vi.fn(),
}));

beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => vi.restoreAllMocks());

test.each([
    {
        scenario: "clean state",
        report: {
            chainDetails: {},
            onChainState: {},
            sheetState: {},
            changes: [],
            validationWarnings: [],
        },
        exitCode: 0,
        message:
            "SafeHarbor verification passed: no updates or validation warnings.",
    },
    {
        scenario: "pending changes",
        report: {
            chainDetails: {},
            onChainState: {},
            sheetState: {},
            changes: [{ fn: "removeChains", args: [["eip155:8453"]] }],
            validationWarnings: [],
        },
        exitCode: 2,
        message:
            "SafeHarbor verification failed: 1 update(s), 0 validation warning(s).",
    },
    {
        scenario: "blocked planning",
        report: {
            chainDetails: {},
            onChainState: {},
            sheetState: {},
            changes: [],
            validationWarnings: [
                {
                    code: "UNKNOWN_ONCHAIN_CHAIN",
                    context: { chainId: "eip155:8453" },
                },
            ],
        },
        exitCode: 2,
        message:
            "SafeHarbor verification failed: 0 update(s), 1 validation warning(s).",
    },
])(
    "reports $scenario without generating a payload",
    ({ report, exitCode, message }) => {
        expect(verify(report)).toBe(exitCode);
        expect(console.log.mock.calls).toEqual([[message]]);
        expect(console.warn).not.toHaveBeenCalled();
        expect(generatePayload).not.toHaveBeenCalled();
    },
);
