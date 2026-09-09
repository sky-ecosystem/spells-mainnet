import { JsonRpcProvider } from "ethers";
import { expect, test, vi } from "vitest";
import { createChainlogReader } from "../src/agreement/chainlog.js";

test("loads the Safe Harbor agreement address from the Chainlog", async () => {
    const provider = new JsonRpcProvider("https://rpc.example");
    const call = vi
        .spyOn(JsonRpcProvider.prototype, "call")
        .mockResolvedValue(
            "0x0000000000000000000000007000000000000000000000000000000000000001",
        );

    try {
        const getChainlogAddress = createChainlogReader(provider);
        expect(call).not.toHaveBeenCalled();
        expect(await getChainlogAddress("SAFE_HARBOR_AGREEMENT")).toBe(
            "0x7000000000000000000000000000000000000001",
        );
        expect(call).toHaveBeenCalledExactlyOnceWith({
            to: "0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F",
            data: "0x21f8a721534146455f484152424f525f41475245454d454e540000000000000000000000",
        });
    } finally {
        call.mockRestore();
        provider.destroy();
    }
});
