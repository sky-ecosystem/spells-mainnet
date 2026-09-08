import { Contract, JsonRpcProvider } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AGREEMENT_V3_ABI } from "../src/abis.js";
import { createAgreementReader } from "../src/agreement.js";
import { getChainlogAddress } from "../src/chainlog.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

vi.mock("../src/chainlog.js", () => ({
    getChainlogAddress: vi.fn(),
}));

let provider;
let getAgreementDetails;

beforeEach(() => {
    provider = new JsonRpcProvider("https://rpc.example");
    getAgreementDetails = createAgreementReader({ provider });
});

afterEach(() => {
    provider.destroy();
    vi.resetAllMocks();
});

test("resolves the Agreement and returns its details", async () => {
    expect(getChainlogAddress).not.toHaveBeenCalled();
    expect(Contract).not.toHaveBeenCalled();
    const details = { chains: [] };
    const getDetails = vi.fn().mockResolvedValue(details);
    getChainlogAddress.mockResolvedValue(
        "0x7000000000000000000000000000000000000001",
    );
    Contract.mockReturnValue({ getDetails });

    expect(await getAgreementDetails()).toBe(details);

    expect(getChainlogAddress).toHaveBeenCalledExactlyOnceWith(
        provider,
        "SAFE_HARBOR_AGREEMENT",
    );
    expect(Contract).toHaveBeenCalledExactlyOnceWith(
        "0x7000000000000000000000000000000000000001",
        AGREEMENT_V3_ABI,
        provider,
    );
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
});

test("propagates Chainlog lookup failures", async () => {
    const failure = new Error("Chainlog unavailable");
    getChainlogAddress.mockRejectedValue(failure);

    await expect(getAgreementDetails()).rejects.toBe(failure);
    expect(Contract).not.toHaveBeenCalled();
});

test("propagates Agreement construction failures", async () => {
    const failure = new Error("Invalid Agreement address");
    getChainlogAddress.mockResolvedValue(
        "0x7000000000000000000000000000000000000001",
    );
    Contract.mockImplementation(() => {
        throw failure;
    });

    await expect(getAgreementDetails()).rejects.toBe(failure);
});

test("propagates Agreement state-read failures", async () => {
    const failure = new Error("Agreement state unavailable");
    getChainlogAddress.mockResolvedValue(
        "0x7000000000000000000000000000000000000001",
    );
    Contract.mockReturnValue({
        getDetails: vi.fn().mockRejectedValue(failure),
    });

    await expect(getAgreementDetails()).rejects.toBe(failure);
});
