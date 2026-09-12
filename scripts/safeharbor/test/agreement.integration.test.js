import { Contract } from "ethers";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import AGREEMENT_V3_ABI from "../src/agreement/abis/agreement.json" with { type: "json" };
import CHAIN_VALIDATOR_ABI from "../src/agreement/abis/chainValidator.json" with { type: "json" };
import { createAgreementReader } from "../src/agreement/index.js";
import { createChainlogReader } from "../src/agreement/chainlog.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

vi.mock("../src/agreement/chainlog.js", () => ({
    createChainlogReader: vi.fn(),
}));

const provider = {};
const getChainlogAddress = vi.fn();
let getAgreementState;

beforeEach(() => {
    createChainlogReader.mockReturnValue(getChainlogAddress);
    getAgreementState = createAgreementReader(provider);
});

afterEach(() => {
    vi.resetAllMocks();
});

test("resolves the Agreement and returns normalized state with diagnostics", async () => {
    expect(createChainlogReader).toHaveBeenCalledExactlyOnceWith(provider);
    expect(getChainlogAddress).not.toHaveBeenCalled();
    expect(Contract).not.toHaveBeenCalled();
    const details = {
        chains: [
            {
                caip2ChainId: "eip155:1",
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                accounts: [["0x2000000000000000000000000000000000000001", 2n]],
            },
            {
                caip2ChainId: "eip155:999999",
                assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
                accounts: [
                    ["0x3000000000000000000000000000000000000001", 0n],
                    ["0x3000000000000000000000000000000000000001", 2n],
                ],
            },
        ],
    };
    const getDetails = vi.fn().mockResolvedValue(details);
    getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
    Contract.mockReturnValue({ getDetails });

    expect(await getAgreementState([])).toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 2n,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
            "eip155:999999": {
                accounts: [
                    {
                        accountAddress: "0x3000000000000000000000000000000000000001",
                        childContractScope: 0n,
                    },
                    {
                        accountAddress: "0x3000000000000000000000000000000000000001",
                        childContractScope: 2n,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
            },
        },
        warnings: [
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainId: "eip155:999999",
                    address: "0x3000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 2n,
                },
            },
        ],
    });

    expect(getChainlogAddress).toHaveBeenCalledExactlyOnceWith("SAFE_HARBOR_AGREEMENT");
    expect(Contract).toHaveBeenCalledExactlyOnceWith(
        "0x7000000000000000000000000000000000000001",
        AGREEMENT_V3_ABI,
        provider,
    );
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
});

test("reuses the Chainlog reader without caching the resolved Agreement address", async () => {
    getChainlogAddress
        .mockResolvedValueOnce("0x7000000000000000000000000000000000000001")
        .mockResolvedValueOnce("0x7000000000000000000000000000000000000002");
    Contract.mockReturnValue({
        getDetails: vi.fn().mockResolvedValue({ chains: [] }),
    });

    await expect(getAgreementState([])).resolves.toEqual({
        value: {},
        warnings: [],
    });
    await expect(getAgreementState([])).resolves.toEqual({
        value: {},
        warnings: [],
    });

    expect(createChainlogReader).toHaveBeenCalledExactlyOnceWith(provider);
    expect(getChainlogAddress.mock.calls).toEqual([["SAFE_HARBOR_AGREEMENT"], ["SAFE_HARBOR_AGREEMENT"]]);
    expect(Contract.mock.calls).toEqual([
        ["0x7000000000000000000000000000000000000001", AGREEMENT_V3_ABI, provider],
        ["0x7000000000000000000000000000000000000002", AGREEMENT_V3_ABI, provider],
    ]);
});

test("propagates Chainlog lookup failures", async () => {
    const failure = new Error("Chainlog unavailable");
    getChainlogAddress.mockRejectedValue(failure);

    await expect(getAgreementState([])).rejects.toBe(failure);
    expect(Contract).not.toHaveBeenCalled();
});

test("propagates Agreement construction failures", async () => {
    const failure = new Error("Invalid Agreement address");
    getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
    Contract.mockImplementation(() => {
        throw failure;
    });

    await expect(getAgreementState([])).rejects.toBe(failure);
});

test("propagates Agreement state-read failures", async () => {
    const failure = new Error("Agreement state unavailable");
    getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
    Contract.mockReturnValue({
        getDetails: vi.fn().mockRejectedValue(failure),
    });

    await expect(getAgreementState([])).rejects.toBe(failure);
});

test("returns normalized state and validates only new desired chain IDs exactly", async () => {
    getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
    const getDetails = vi.fn().mockResolvedValue({
        chains: [
            {
                caip2ChainId: "eip155:1",
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                accounts: [["0x2000000000000000000000000000000000000001", 0n]],
            },
        ],
    });
    const getChainValidator = vi.fn().mockResolvedValue("0x8000000000000000000000000000000000000001");
    const isChainValid = vi.fn().mockResolvedValueOnce(true).mockResolvedValueOnce(false).mockResolvedValueOnce(false);
    Contract.mockReturnValueOnce({
        getDetails,
        getChainValidator,
    }).mockReturnValueOnce({ isChainValid });

    await expect(getAgreementState(["eip155:1", "eip155:10", "eip155:999999", "EIP155:1"])).resolves.toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 0n,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [
            { code: "INVALID_CHAIN_ID", context: { chainId: "eip155:999999" } },
            { code: "INVALID_CHAIN_ID", context: { chainId: "EIP155:1" } },
        ],
    });

    expect(isChainValid.mock.calls).toEqual([["eip155:10"], ["eip155:999999"], ["EIP155:1"]]);
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    expect(getChainValidator).toHaveBeenCalledExactlyOnceWith();
    expect(getChainlogAddress).toHaveBeenCalledExactlyOnceWith("SAFE_HARBOR_AGREEMENT");
    expect(Contract.mock.calls).toEqual([
        ["0x7000000000000000000000000000000000000001", AGREEMENT_V3_ABI, provider],
        ["0x8000000000000000000000000000000000000001", CHAIN_VALIDATOR_ABI, provider],
    ]);
});

test("skips validator access when every desired chain already exists", async () => {
    getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
    const getDetails = vi.fn().mockResolvedValue({
        chains: [
            {
                caip2ChainId: "eip155:1",
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                accounts: [["0x2000000000000000000000000000000000000001", 0n]],
            },
        ],
    });
    const getChainValidator = vi.fn();
    Contract.mockReturnValue({ getDetails, getChainValidator });

    await expect(getAgreementState(["eip155:1"])).resolves.toEqual({
        value: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 0n,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        warnings: [],
    });
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    expect(getChainValidator).not.toHaveBeenCalled();
    expect(Contract).toHaveBeenCalledTimes(1);
});

test.each(["getChainValidator", "isChainValid"])(
    "propagates %s RPC failures instead of returning an invalid-chain diagnostic",
    async (method) => {
        const failure = new Error("Validator unavailable");
        getChainlogAddress.mockResolvedValue("0x7000000000000000000000000000000000000001");
        const getChainValidator = vi.fn().mockResolvedValue("0x8000000000000000000000000000000000000001");
        const isChainValid = vi.fn().mockResolvedValue(true);
        const methods = { getChainValidator, isChainValid };
        methods[method].mockRejectedValue(failure);
        Contract.mockReturnValueOnce({
            getDetails: vi.fn().mockResolvedValue({ chains: [] }),
            getChainValidator,
        }).mockReturnValueOnce({ isChainValid });

        await expect(getAgreementState(["eip155:1"])).rejects.toBe(failure);
    },
);
