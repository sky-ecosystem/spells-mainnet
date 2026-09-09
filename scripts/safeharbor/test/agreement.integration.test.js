import { Contract, JsonRpcProvider } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { AGREEMENT_V3_ABI } from "../src/agreement/abis.js";
import { createAgreementReader } from "../src/agreement/index.js";
import { getChainlogAddress } from "../src/agreement/chainlog.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

vi.mock("../src/agreement/chainlog.js", () => ({
    getChainlogAddress: vi.fn(),
}));

let provider;
let getAgreementState;

beforeEach(() => {
    provider = new JsonRpcProvider("https://rpc.example");
    getAgreementState = createAgreementReader({ provider });
});

afterEach(() => {
    provider.destroy();
    vi.resetAllMocks();
});

test("resolves the Agreement and returns normalized state with diagnostics", async () => {
    expect(getChainlogAddress).not.toHaveBeenCalled();
    expect(Contract).not.toHaveBeenCalled();
    const details = {
        chains: [
            {
                caip2ChainId: "eip155:1",
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
                accounts: [["0x2000000000000000000000000000000000000001", 2n]],
            },
            {
                caip2ChainId: "eip155:999999",
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000002",
                accounts: [["0x3000000000000000000000000000000000000001", 0n]],
            },
        ],
    };
    const getDetails = vi.fn().mockResolvedValue(details);
    getChainlogAddress.mockResolvedValue(
        "0x7000000000000000000000000000000000000001",
    );
    Contract.mockReturnValue({ getDetails });

    expect(
        await getAgreementState({ name: { "eip155:1": "ETHEREUM" } }),
    ).toEqual({
        value: {
            ETHEREUM: {
                accounts: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2n,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:999999" },
            },
        ],
    });

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

    await expect(getAgreementState({ name: {} })).rejects.toBe(failure);
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

    await expect(getAgreementState({ name: {} })).rejects.toBe(failure);
});

test("propagates Agreement state-read failures", async () => {
    const failure = new Error("Agreement state unavailable");
    getChainlogAddress.mockResolvedValue(
        "0x7000000000000000000000000000000000000001",
    );
    Contract.mockReturnValue({
        getDetails: vi.fn().mockRejectedValue(failure),
    });

    await expect(getAgreementState({ name: {} })).rejects.toBe(failure);
});
