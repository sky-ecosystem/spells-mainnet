import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { setImmediate } from "node:timers/promises";
import { reconcile } from "./reconcile.js";

beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Unexpected fetch")));
});

afterEach(() => {
    vi.unstubAllGlobals();
});

test("loads metadata and Sheet state before passing desired chain IDs to the Agreement reader", async () => {
    let resolveMetadata;
    const metadata = new Promise((resolve) => {
        resolveMetadata = resolve;
    });
    let resolveSheetState;
    const sheetState = new Promise((resolve) => {
        resolveSheetState = resolve;
    });
    const getSheetChainDetails = vi.fn(() => metadata);
    const getSheetState = vi.fn(() => sheetState);
    const getAgreementState = vi.fn().mockResolvedValue({
        value: {},
        warnings: [],
    });
    const settled = vi.fn();
    const result = reconcile({
        getAgreementState,
        getSheetState,
        getSheetChainDetails,
    });
    result.then(settled, settled);

    expect(getSheetChainDetails).toHaveBeenCalledExactlyOnceWith();
    expect(getSheetState).not.toHaveBeenCalled();
    expect(getAgreementState).not.toHaveBeenCalled();

    resolveMetadata({
        value: { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
        warnings: [],
    });
    await setImmediate();

    expect(getSheetState).toHaveBeenCalledExactlyOnceWith({
        caip2ChainId: {},
        assetRecoveryAddress: {},
        name: {},
    });
    expect(getAgreementState).not.toHaveBeenCalled();
    expect(settled).not.toHaveBeenCalled();

    resolveSheetState({ value: {}, warnings: [] });
    await expect(result).resolves.toMatchObject({
        changes: [],
        validationWarnings: [],
    });
    expect(getAgreementState).toHaveBeenCalledExactlyOnceWith([]);
});

test("does not read either state when chain metadata fails", async () => {
    const failure = new Error("Metadata unavailable");
    const getAgreementState = vi.fn();
    const getSheetState = vi.fn();

    await expect(
        reconcile({
            getAgreementState,
            getSheetState,
            getSheetChainDetails: vi.fn().mockRejectedValue(failure),
        }),
    ).rejects.toMatchObject({
        message: "Metadata unavailable",
        source: "sheetChainDetails",
        cause: failure,
    });
    expect(getSheetState).not.toHaveBeenCalled();
    expect(getAgreementState).not.toHaveBeenCalled();
});

test.each([
    ["getSheetChainDetails", "sheetChainDetails", "reject"],
    ["getSheetState", "sheetState", "throw"],
    ["getAgreementState", "agreementOnChainState", "reject"],
])("attributes %s failures (%s, %s) without changing the original error", async (loader, source, mode) => {
    const diagnostic = {
        code: "MISSING_SHEET_HEADERS",
        context: { missingHeaders: ["Status"] },
    };
    const failure = Object.freeze(Object.assign(new Error("Source unavailable"), { diagnostic }));
    const loaders = {
        getSheetChainDetails: vi.fn().mockResolvedValue({
            value: { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
            warnings: [],
        }),
        getSheetState: vi.fn().mockResolvedValue({ value: {}, warnings: [] }),
        getAgreementState: vi.fn().mockResolvedValue({ value: {}, warnings: [] }),
    };
    loaders[loader].mockImplementation(() => {
        if (mode === "throw") {
            throw failure;
        }
        return Promise.reject(failure);
    });

    const error = await reconcile(loaders).catch((error) => error);

    expect(error).toBeInstanceOf(Error);
    expect(error).not.toBe(failure);
    expect(error.message).toBe("Source unavailable");
    expect(error.source).toBe(source);
    expect(error.cause).toBe(failure);
    expect(error.diagnostic).toBe(diagnostic);
    expect(failure).not.toHaveProperty("source");
    expect(failure).not.toHaveProperty("cause");
});

test("preserves a non-Error rejection as the source error's cause", async () => {
    await expect(
        reconcile({
            getSheetChainDetails: vi.fn().mockRejectedValue("Metadata unavailable"),
            getSheetState: vi.fn(),
            getAgreementState: vi.fn(),
        }),
    ).rejects.toMatchObject({
        message: "Metadata unavailable",
        source: "sheetChainDetails",
        cause: "Metadata unavailable",
    });
});
