import { afterEach, describe, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({
    Contract: vi.fn(),
    JsonRpcProvider: vi.fn((rpcUrl) => ({ rpcUrl })),
    encodeBytes32String: vi.fn((value) => `bytes32:${value}`),
    getContractAddress: vi.fn(),
    getChainlogAddress: vi.fn(),
}));

vi.mock("ethers", () => ({
    Contract: mocks.Contract,
    JsonRpcProvider: mocks.JsonRpcProvider,
    encodeBytes32String: mocks.encodeBytes32String,
}));

import { AGREEMENT_V3_ABI, CHAINLOG_ABI } from "../src/abis.js";
import { createAgreementInstance } from "../src/utils/contractUtils.js";

describe("createAgreementInstance", () => {
    afterEach(() => {
        vi.clearAllMocks();
    });

    test("loads the Safe Harbor agreement address from the Chainlog", async () => {
        const chainlog = {
            getAddress: mocks.getContractAddress,
            "getAddress(bytes32)": mocks.getChainlogAddress,
        };
        const agreement = {
            address: "0x7000000000000000000000000000000000000001",
        };

        mocks.getChainlogAddress.mockResolvedValue(agreement.address);
        mocks.Contract.mockReturnValueOnce(chainlog).mockReturnValueOnce(
            agreement,
        );

        const result = await createAgreementInstance("https://rpc.example");

        expect(mocks.Contract).toHaveBeenNthCalledWith(
            1,
            "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F",
            CHAINLOG_ABI,
            { rpcUrl: "https://rpc.example" },
        );
        expect(mocks.encodeBytes32String).toHaveBeenCalledWith(
            "SAFE_HARBOR_AGREEMENT",
        );
        expect(mocks.getChainlogAddress).toHaveBeenCalledWith(
            "bytes32:SAFE_HARBOR_AGREEMENT",
        );
        expect(mocks.getContractAddress).not.toHaveBeenCalled();
        expect(mocks.Contract).toHaveBeenNthCalledWith(
            2,
            agreement.address,
            AGREEMENT_V3_ABI,
            { rpcUrl: "https://rpc.example" },
        );
        expect(result).toBe(agreement);
    });
});
