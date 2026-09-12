import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { generatePayload } from "../../generation/index.js";
import { generate } from "./generate.js";

vi.mock("../../generation/index.js", () => ({
    generatePayload: vi.fn(),
}));

beforeEach(() => {
    vi.resetAllMocks();
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => vi.restoreAllMocks());

test("prints generated Solidity and the success summary for pending changes", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {},
        sheetState: {},
        changes: [{ fn: "removeChains", args: [["eip155:8453"]] }],
        validationWarnings: [],
    };
    generatePayload.mockReturnValue({
        updates: [
            {
                fn: "removeChains",
                args: [["eip155:8453"]],
                calldata: "0x1234",
            },
        ],
        solidityCode: "generated Solidity",
    });

    expect(generate(report)).toBe(0);
    expect(generatePayload).toHaveBeenCalledExactlyOnceWith([{ fn: "removeChains", args: [["eip155:8453"]] }]);
    expect(console.log).toHaveBeenCalledExactlyOnceWith("generated Solidity");
    expect(console.warn).toHaveBeenCalledExactlyOnceWith("✅ Payload generation completed successfully.");
    expect(report.changes).toEqual([{ fn: "removeChains", args: [["eip155:8453"]] }]);
});

test("prints only the no-updates summary for clean state", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {},
        sheetState: {},
        changes: [],
        validationWarnings: [],
    };
    generatePayload.mockReturnValue({ updates: [], solidityCode: "" });

    expect(generate(report)).toBe(0);
    expect(generatePayload).toHaveBeenCalledExactlyOnceWith([]);
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn).toHaveBeenCalledExactlyOnceWith("✅ No updates to generate");
});

test("blocks generation on validation warnings without printing individual diagnostics", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {},
        sheetState: {},
        changes: [],
        validationWarnings: [
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:8453" },
            },
        ],
    };

    expect(generate(report)).toBe(2);
    expect(generatePayload).not.toHaveBeenCalled();
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn).toHaveBeenCalledExactlyOnceWith("❌ Payload generation blocked: 1 validation warning(s).");
});

test("propagates generation errors to the CLI", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {},
        sheetState: {},
        changes: [{ fn: "removeChains", args: [["eip155:8453"]] }],
        validationWarnings: [],
    };
    generatePayload.mockImplementation(() => {
        throw new Error("Unable to encode payload");
    });

    expect(() => generate(report)).toThrow("Unable to encode payload");
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn).not.toHaveBeenCalled();
});
