import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { dedent } from "../../../test/helpers/dedent.js";
import { generate } from "./generate.js";

beforeEach(() => {
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => vi.restoreAllMocks());

test("prints real encoded Solidity for pending changes", () => {
    const report = {
        chainDetails: {},
        onChainState: {},
        sheetState: {},
        changes: [{ fn: "removeChains", args: [["eip155:8453"]] }],
        validationWarnings: [],
    };

    expect(generate(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            dedent`
                bytes[] memory calldatas = new bytes[](1);

                // Remove chains: eip155:8453
                calldatas[0] = hex'1e12ef29000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b6569703135353a38343533000000000000000000000000000000000000000000';

                _updateSafeHarbor(calldatas);
            `,
        ],
    ]);
    expect(console.warn.mock.calls).toEqual([
        ["Payload generation completed successfully."],
    ]);
    expect(report.changes).toEqual([
        { fn: "removeChains", args: [["eip155:8453"]] },
    ]);
});

test("prints only the no-updates summary for clean state", () => {
    const report = {
        chainDetails: {},
        onChainState: {},
        sheetState: {},
        changes: [],
        validationWarnings: [],
    };

    expect(generate(report)).toBe(0);
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn.mock.calls).toEqual([["No updates to generate"]]);
});

test("blocks generation on validation warnings without printing individual diagnostics", () => {
    const report = {
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
    };

    expect(generate(report)).toBe(2);
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn.mock.calls).toEqual([
        ["Payload generation blocked: 1 validation warning(s)."],
    ]);
});

test("propagates encoding errors to the CLI", () => {
    const report = {
        chainDetails: {},
        onChainState: {},
        sheetState: {},
        changes: [{ fn: "unknownOperation", args: [] }],
        validationWarnings: [],
    };

    expect(() => generate(report)).toThrow();
    expect(console.log).not.toHaveBeenCalled();
    expect(console.warn).not.toHaveBeenCalled();
});
