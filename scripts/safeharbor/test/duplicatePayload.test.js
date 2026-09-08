import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { Interface } from "ethers";
import { generatePayload } from "../src/generatePayload.js";
import { generateUpdates } from "../src/generateUpdates.js";

vi.mock("../src/generateUpdates.js", { spy: true });

let warnings;
let errors;
let encoding;

beforeEach(() => {
    vi.clearAllMocks();
    vi.stubGlobal("fetch", vi.fn());
    warnings = vi.spyOn(console, "warn").mockImplementation(() => {});
    errors = vi.spyOn(console, "error").mockImplementation(() => {});
    encoding = vi.spyOn(Interface.prototype, "encodeFunctionData");
});

afterEach(() => {
    try {
        expect(errors).not.toHaveBeenCalled();
    } finally {
        warnings.mockRestore();
        errors.mockRestore();
        encoding.mockRestore();
        vi.unstubAllGlobals();
    }
});

test.each([
    {
        scenario: "duplicate chain names",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nETHEREUM,eip155:2,0x1000000000000000000000000000000000000002\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: ["Duplicate chain name found in CSV: ETHEREUM"],
    },
    {
        scenario: "duplicate chain IDs",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\nOTHER,eip155:1,0x1000000000000000000000000000000000000002\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: ["Duplicate chain ID found in CSV: eip155:1"],
    },
    {
        scenario: "duplicate additions to an existing chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
        ],
    },
    {
        scenario: "duplicate accounts in a new chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: { chains: [] },
        expectedWarnings: [
            "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
        ],
    },
    {
        scenario: "conflicting desired scopes",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
        ],
    },
    {
        scenario: "duplicate current accounts with no other differences",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
        ],
    },
    {
        scenario: "conflicting current scopes",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 2n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
        ],
    },
    {
        scenario: "duplicate current accounts on a removed chain",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
        ],
    },
    {
        scenario: "duplicate accounts in both sources",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["0x2000000000000000000000000000000000000002", 0n],
                        ["0x2000000000000000000000000000000000000002", 2n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000001",
            "Duplicate account address in on-chain state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
        ],
    },
])(
    "returns diagnostics only for $scenario",
    async ({ chainCSV, contractCSV, details, expectedWarnings }) => {
        fetch
            .mockResolvedValueOnce(
                new Response(chainCSV, {
                    headers: { "content-type": "text/csv" },
                }),
            )
            .mockResolvedValueOnce(
                new Response(contractCSV, {
                    headers: { "content-type": "text/csv" },
                }),
            );
        const agreementContract = {
            getDetails: vi.fn().mockResolvedValue(details),
        };

        await expect(generatePayload(agreementContract)).resolves.toEqual({
            updates: [],
            solidityCode: "",
            validationWarnings: expectedWarnings,
        });
        expect(generateUpdates).not.toHaveBeenCalled();
        expect(encoding).not.toHaveBeenCalled();
        for (const warning of expectedWarnings) {
            expect(warnings).toHaveBeenCalledWith(warning);
        }
    },
);
