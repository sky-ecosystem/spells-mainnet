import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { Interface } from "ethers";
import { generateSolidity } from "../../generation/solidity.js";
import { inspect } from "./inspect.js";

vi.mock("../../generation/solidity.js", () => ({
    generateSolidity: vi.fn(),
}));

beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(Interface.prototype, "encodeFunctionData");
});

afterEach(() => vi.restoreAllMocks());

test("prints an empty changes array for clean state", () => {
    const report = {
        chainDetails: {},
        onChainState: {},
        sheetState: {},
        changes: [],
        validationWarnings: [],
    };

    expect(inspect(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            `{
  "chainDetails": {},
  "onChainState": {},
  "sheetState": {},
  "changes": [],
  "validationWarnings": []
}`,
        ],
    ]);
    expect(console.warn).not.toHaveBeenCalled();
    expect(Interface.prototype.encodeFunctionData).not.toHaveBeenCalled();
    expect(generateSolidity).not.toHaveBeenCalled();
});

test("prints raw state and changes with bigint values as decimal strings without mutation", () => {
    const report = {
        chainDetails: {
            caip2ChainId: { Ethereum: "eip155:1" },
            name: { "eip155:1": "Ethereum" },
            assetRecoveryAddress: {
                Ethereum: "0x1000000000000000000000000000000000000001",
            },
        },
        onChainState: {
            Ethereum: {
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
        sheetState: {},
        changes: [{ fn: "removeChains", args: [["eip155:1"]] }],
        validationWarnings: [],
    };

    expect(inspect(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            `{
  "chainDetails": {
    "caip2ChainId": {
      "Ethereum": "eip155:1"
    },
    "name": {
      "eip155:1": "Ethereum"
    },
    "assetRecoveryAddress": {
      "Ethereum": "0x1000000000000000000000000000000000000001"
    }
  },
  "onChainState": {
    "Ethereum": {
      "accounts": [
        {
          "accountAddress": "0x2000000000000000000000000000000000000001",
          "childContractScope": "2"
        }
      ],
      "assetRecoveryAddress": "0x1000000000000000000000000000000000000001"
    }
  },
  "sheetState": {},
  "changes": [
    {
      "fn": "removeChains",
      "args": [
        [
          "eip155:1"
        ]
      ]
    }
  ],
  "validationWarnings": []
}`,
        ],
    ]);
    expect(report.onChainState.Ethereum.accounts[0].childContractScope).toBe(
        2n,
    );
    expect(report.changes).toEqual([
        { fn: "removeChains", args: [["eip155:1"]] },
    ]);
    expect(console.warn).not.toHaveBeenCalled();
    expect(Interface.prototype.encodeFunctionData).not.toHaveBeenCalled();
    expect(generateSolidity).not.toHaveBeenCalled();
});

test("prints blocked planning as null with diagnostics and no executable artifacts", () => {
    const report = {
        chainDetails: {},
        onChainState: {},
        sheetState: {},
        changes: null,
        validationWarnings: [
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:8453" },
            },
        ],
    };

    expect(inspect(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            `{
  "chainDetails": {},
  "onChainState": {},
  "sheetState": {},
  "changes": null,
  "validationWarnings": [
    {
      "code": "UNKNOWN_ONCHAIN_CHAIN",
      "context": {
        "chainId": "eip155:8453"
      }
    }
  ]
}`,
        ],
    ]);
    expect(report.changes).toBeNull();
    expect(console.warn).not.toHaveBeenCalled();
    expect(Interface.prototype.encodeFunctionData).not.toHaveBeenCalled();
    expect(generateSolidity).not.toHaveBeenCalled();
});
