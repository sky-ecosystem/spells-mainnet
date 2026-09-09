import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { setImmediate } from "node:timers/promises";
import { reconcile } from "./reconcile.js";

beforeEach(() => {
    vi.stubGlobal(
        "fetch",
        vi.fn().mockRejectedValue(new Error("Unexpected fetch")),
    );
});

afterEach(() => {
    vi.unstubAllGlobals();
});

test("waits for metadata before reading the Sheet state and Agreement concurrently", async () => {
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
    expect(getAgreementState).toHaveBeenCalledExactlyOnceWith({
        caip2ChainId: {},
        assetRecoveryAddress: {},
        name: {},
    });
    expect(settled).not.toHaveBeenCalled();

    resolveSheetState({ value: {}, warnings: [] });
    await expect(result).resolves.toMatchObject({
        changes: [],
        validationWarnings: [],
    });
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
    ).rejects.toBe(failure);
    expect(getSheetState).not.toHaveBeenCalled();
    expect(getAgreementState).not.toHaveBeenCalled();
});
