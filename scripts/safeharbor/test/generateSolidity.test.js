import { expect, test } from "vitest";
import { generateSolidityCode } from "../src/utils/generateSolidity.js";

test("wraps update calldata in the SafeHarbor Solidity template", () => {
    const code = generateSolidityCode([
        {
            function: "removeChains",
            args: [["eip155:1"]],
            calldata: "0x1234",
        },
    ]);

    expect(code).toContain("bytes[] memory calldatas = new bytes[](1)");
    expect(code).toContain("// Remove chains: eip155:1");
    expect(code).toContain("calldatas[0] = hex'1234'");
    expect(code).toContain("_updateSafeHarbor(calldatas)");
});
