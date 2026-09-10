import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { dedent } from "../../utils/dedent.js";
import { generatePayload } from "../../generation/index.js";
import { inspect } from "./inspect.js";

vi.mock("../../generation/index.js", () => ({
    generatePayload: vi.fn(),
}));

beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => vi.restoreAllMocks());

test("prints an empty changes array for clean state", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {},
        sheetState: {},
        changes: [],
        validationWarnings: [],
    };

    expect(inspect(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            dedent`
                {
                  "sheetChainDetails": {},
                  "agreementOnChainState": {},
                  "sheetState": {},
                  "changes": [],
                  "validationWarnings": []
                }
            `,
        ],
    ]);
    expect(console.warn).not.toHaveBeenCalled();
    expect(generatePayload).not.toHaveBeenCalled();
});

test("prints raw state and changes with bigint values as decimal strings without mutation", () => {
    const report = {
        sheetChainDetails: {
            caip2ChainId: { Ethereum: "eip155:1" },
            name: { "eip155:1": "Ethereum" },
            assetRecoveryAddress: {
                Ethereum: "0x1000000000000000000000000000000000000001",
            },
        },
        agreementOnChainState: {
            "eip155:1": {
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
        sheetState: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 2,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                ],
                assetRecoveryAddress:
                    "0x1000000000000000000000000000000000000001",
            },
        },
        changes: [
            {
                fn: "addAccounts",
                args: [
                    "eip155:1",
                    [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000002",
                            childContractScope: 0,
                        },
                    ],
                ],
            },
        ],
        validationWarnings: [],
    };

    expect(inspect(report)).toBe(0);
    expect(console.log.mock.calls).toEqual([
        [
            dedent`
                {
                  "sheetChainDetails": {
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
                  "agreementOnChainState": {
                    "eip155:1": {
                      "accounts": [
                        {
                          "accountAddress": "0x2000000000000000000000000000000000000001",
                          "childContractScope": "2"
                        }
                      ],
                      "assetRecoveryAddress": "0x1000000000000000000000000000000000000001"
                    }
                  },
                  "sheetState": {
                    "eip155:1": {
                      "accounts": [
                        {
                          "accountAddress": "0x2000000000000000000000000000000000000001",
                          "childContractScope": 2
                        },
                        {
                          "accountAddress": "0x2000000000000000000000000000000000000002",
                          "childContractScope": 0
                        }
                      ],
                      "assetRecoveryAddress": "0x1000000000000000000000000000000000000001"
                    }
                  },
                  "changes": [
                    {
                      "fn": "addAccounts",
                      "args": [
                        "eip155:1",
                        [
                          {
                            "accountAddress": "0x2000000000000000000000000000000000000002",
                            "childContractScope": 0
                          }
                        ]
                      ]
                    }
                  ],
                  "validationWarnings": []
                }
            `,
        ],
    ]);
    expect(
        report.agreementOnChainState["eip155:1"].accounts[0].childContractScope,
    ).toBe(2n);
    expect(report.sheetState["eip155:1"].accounts[0].childContractScope).toBe(
        2,
    );
    expect(report.changes).toEqual([
        {
            fn: "addAccounts",
            args: [
                "eip155:1",
                [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                ],
            ],
        },
    ]);
    expect(console.warn).not.toHaveBeenCalled();
    expect(generatePayload).not.toHaveBeenCalled();
});

test("prints no changes with diagnostics when planning is blocked", () => {
    const report = {
        sheetChainDetails: {},
        agreementOnChainState: {
            "eip155:8453": {
                accounts: [{ accountAddress: "A", childContractScope: 2n }],
                assetRecoveryAddress: "recovery",
            },
        },
        sheetState: {},
        changes: [],
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
            dedent`
                {
                  "sheetChainDetails": {},
                  "agreementOnChainState": {
                    "eip155:8453": {
                      "accounts": [
                        {
                          "accountAddress": "A",
                          "childContractScope": "2"
                        }
                      ],
                      "assetRecoveryAddress": "recovery"
                    }
                  },
                  "sheetState": {},
                  "changes": [],
                  "validationWarnings": [
                    {
                      "code": "UNKNOWN_ONCHAIN_CHAIN",
                      "context": {
                        "chainId": "eip155:8453"
                      }
                    }
                  ]
                }
            `,
        ],
    ]);
    expect(report.changes).toEqual([]);
    expect(console.warn).not.toHaveBeenCalled();
    expect(generatePayload).not.toHaveBeenCalled();
});
