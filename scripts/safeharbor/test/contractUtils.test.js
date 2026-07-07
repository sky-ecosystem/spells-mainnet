import { afterEach, describe, expect, test, vi } from "vitest";

const contractCalls = [];
const getContractAddress = vi.fn();
const getChainlogAddress = vi.fn();
const encodeBytes32String = vi.fn((value) => `bytes32:${value}`);

vi.mock("ethers", () => ({
    Contract: vi.fn((address, abi, provider) => {
        contractCalls.push({ address, abi, provider });

        if (contractCalls.length === 1) {
            return {
                getAddress: getContractAddress,
                "getAddress(bytes32)": getChainlogAddress,
            };
        }

        return { address, abi, provider };
    }),
    JsonRpcProvider: vi.fn((rpcUrl) => ({ rpcUrl })),
    encodeBytes32String,
}));

describe("createAgreementInstance", () => {
    afterEach(() => {
        vi.clearAllMocks();
        contractCalls.length = 0;
    });

    test("loads the Safe Harbor agreement address from the Chainlog", async () => {
        getContractAddress.mockResolvedValue(
            "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F",
        );
        getChainlogAddress.mockResolvedValue(
            "0x0000000000000000000000000000000000000529",
        );

        const { createAgreementInstance } = await import(
            "../src/utils/contractUtils.js"
        );
        const { CHAINLOG_ABI } = await import("../src/abis.js");
        const { AGREEMENT_V3_ABI } = await import("../src/abis.js");

        const agreement = await createAgreementInstance("https://rpc.example");

        expect(contractCalls[0]).toEqual({
            address: "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F",
            abi: CHAINLOG_ABI,
            provider: { rpcUrl: "https://rpc.example" },
        });
        expect(encodeBytes32String).toHaveBeenCalledWith(
            "SAFE_HARBOR_AGREEMENT",
        );
        expect(getChainlogAddress).toHaveBeenCalledWith(
            "bytes32:SAFE_HARBOR_AGREEMENT",
        );
        expect(getContractAddress).not.toHaveBeenCalled();
        expect(contractCalls[1]).toEqual({
            address: "0x0000000000000000000000000000000000000529",
            abi: AGREEMENT_V3_ABI,
            provider: { rpcUrl: "https://rpc.example" },
        });
        expect(agreement.address).toBe(
            "0x0000000000000000000000000000000000000529",
        );
    });
});
