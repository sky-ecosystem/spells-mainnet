import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { Contract, Interface, JsonRpcProvider } from "ethers";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";
import { reconcile } from "../src/reconciliation/index.js";
import { createAgreementReader } from "../src/agreement/index.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

const getDetails = vi.fn();
let provider;

beforeEach(() => {
    provider = new JsonRpcProvider("https://rpc.example");
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi
            .fn()
            .mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });
    vi.stubGlobal("fetch", vi.fn());
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(console, "log").mockImplementation(() => {});
});

afterEach(() => {
    try {
        expect(console.warn).not.toHaveBeenCalled();
        expect(console.error).not.toHaveBeenCalled();
        expect(console.log).not.toHaveBeenCalled();
    } finally {
        provider.destroy();
        vi.unstubAllGlobals();
        vi.restoreAllMocks();
        vi.resetAllMocks();
    }
});

function csvResponse(csv) {
    return new Response(csv, { headers: { "content-type": "text/csv" } });
}

test.each([
    {
        status: 503,
        headers: { "content-type": "text/html" },
        diagnostic: { code: "HTTP_ERROR", context: { status: 503 } },
    },
    {
        status: 200,
        headers: { "content-type": "text/html" },
        diagnostic: { code: "INVALID_CSV_CONTENT_TYPE" },
    },
    {
        status: 200,
        headers: {},
        diagnostic: { code: "INVALID_CSV_CONTENT_TYPE" },
    },
])(
    "rejects invalid CSV response $diagnostic.code without reporting",
    async ({ status, headers, diagnostic }) => {
        fetch.mockResolvedValue(new Response(null, { status, headers }));

        await expect(getSheetChainDetails()).rejects.toMatchObject({
            diagnostic,
        });
    },
);

test("propagates fetch failures unchanged without reporting", async () => {
    const failure = new Error("Network unavailable");
    fetch.mockRejectedValue(failure);

    await expect(getSheetChainDetails()).rejects.toBe(failure);
});

describe("contracts CSV headers", () => {
    test.each([
        ["Status in a header-only file", "Chain,Address,isFactory\n", "Status"],
        [
            "Status with records",
            "Chain,Address,isFactory\nETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
            "Status",
        ],
        ["Chain in a header-only file", "Status,Address,isFactory\n", "Chain"],
        [
            "Chain with records",
            "Status,Address,isFactory\nACTIVE,0x2000000000000000000000000000000000000001,FALSE\n",
            "Chain",
        ],
        [
            "Address in a header-only file",
            "Status,Chain,isFactory\n",
            "Address",
        ],
        [
            "Address with records",
            "Status,Chain,isFactory\nACTIVE,ETHEREUM,FALSE\n",
            "Address",
        ],
        [
            "factory flag in a header-only file",
            "Status,Chain,Address\n",
            "isFactory",
        ],
        [
            "factory flag with records",
            "Status,Chain,Address\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001\n",
            "isFactory",
        ],
        ["all headers in an empty file", "", "Status"],
        ["all headers in a blank file", " \n\n", "Status"],
    ])("rejects missing %s", async (_scenario, csv, missingHeader) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(getSheetState()).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: {
                    missingHeaders: expect.arrayContaining([missingHeader]),
                },
            },
        });
    });

    test.each([
        [
            "isFactory",
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nINACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE\n",
        ],
        [
            "IsFactory",
            "Status,Chain,Address,IsFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nINACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE\n",
        ],
        [
            "reordered, quoted headers and an extra column",
            'Notes,"Address",IsFactory,Chain,Status\n"reviewed, factory",0x2000000000000000000000000000000000000001,TRUE,ETHEREUM,ACTIVE\nreviewed,0x2000000000000000000000000000000000000002,FALSE,ETHEREUM,ACTIVE\nold,0x2000000000000000000000000000000000000003,TRUE,ETHEREUM,INACTIVE\n',
        ],
        [
            "both factory aliases without changing flag semantics",
            "Status,Chain,Address,isFactory,IsFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE,FALSE\nINACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE,TRUE\n",
        ],
    ])("accepts %s", async (_scenario, csv) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(
            getSheetState({
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            }),
        ).resolves.toEqual({
            value: {
                ETHEREUM: [
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
            },
            warnings: [],
        });
        expect(fetch).toHaveBeenCalledExactlyOnceWith(
            "https://docs.google.com/spreadsheets/d/1e_KOYOeBGaA5EG3Xqco6lOP_a0zV4Vrm3w5-dqFk00U/export?format=csv&gid=1121763694",
        );
    });
});

describe("chain metadata CSV headers", () => {
    test.each([
        [
            "Name in a header-only file",
            "Chain Id,Asset Recovery Address\n",
            "Name",
        ],
        [
            "Name with records",
            "Chain Id,Asset Recovery Address\neip155:1,0x1000000000000000000000000000000000000001\n",
            "Name",
        ],
        [
            "Chain Id in a header-only file",
            "Name,Asset Recovery Address\n",
            "Chain Id",
        ],
        [
            "Chain Id with records",
            "Name,Asset Recovery Address\nETHEREUM,0x1000000000000000000000000000000000000001\n",
            "Chain Id",
        ],
        [
            "Asset Recovery Address in a header-only file",
            "Name,Chain Id\n",
            "Asset Recovery Address",
        ],
        [
            "Asset Recovery Address with records",
            "Name,Chain Id\nETHEREUM,eip155:1\n",
            "Asset Recovery Address",
        ],
        ["all headers in an empty file", "", "Name"],
        ["all headers in a blank file", "\n \n", "Name"],
    ])("rejects missing %s", async (_scenario, csv, missingHeader) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(getSheetChainDetails()).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: {
                    missingHeaders: expect.arrayContaining([missingHeader]),
                },
            },
        });
    });

    test("accepts a header-only file", async () => {
        fetch.mockResolvedValue(
            csvResponse("Name,Chain Id,Asset Recovery Address\n"),
        );

        await expect(getSheetChainDetails()).resolves.toEqual({
            value: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            warnings: [],
        });
    });

    test("accepts reordered, quoted headers and an extra column", async () => {
        fetch.mockResolvedValue(
            csvResponse(
                'Notes,"Asset Recovery Address",Name,Chain Id\n"reviewed, mainnet",0x1000000000000000000000000000000000000001,ETHEREUM,eip155:1\n',
            ),
        );

        await expect(getSheetChainDetails()).resolves.toEqual({
            value: {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
            warnings: [],
        });
    });

    test("trims headers and values and ignores blank rows", async () => {
        fetch.mockResolvedValue(
            csvResponse(
                " Name , Chain Id , Asset Recovery Address , Notes \n,,,\n   ,   ,   ,   \n\n ETHEREUM , eip155:1 , 0x1000000000000000000000000000000000000001 , reviewed \n",
            ),
        );

        await expect(getSheetChainDetails()).resolves.toEqual({
            value: {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
            warnings: [],
        });
        expect(fetch).toHaveBeenCalledExactlyOnceWith(
            "https://docs.google.com/spreadsheets/d/1e_KOYOeBGaA5EG3Xqco6lOP_a0zV4Vrm3w5-dqFk00U/export?format=csv&gid=1620276618",
        );
    });
});

describe("malformed CSV", () => {
    test.each([
        [
            "contracts with a malformed header",
            getSheetState,
            'Status,Chain,Address,"isFactory\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "contracts with an unterminated quote",
            getSheetState,
            'Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,"0x2000000000000000000000000000000000000001,FALSE\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "contracts with too few fields",
            getSheetState,
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "contracts with too many fields",
            getSheetState,
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE,EXTRA\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "chain metadata with a malformed header",
            getSheetChainDetails,
            'Name,Chain Id,"Asset Recovery Address\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "chain metadata with an unterminated quote",
            getSheetChainDetails,
            'Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,"0x1000000000000000000000000000000000000001\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "chain metadata with too few fields",
            getSheetChainDetails,
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "chain metadata with too many fields",
            getSheetChainDetails,
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001,EXTRA\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
    ])("rejects %s", async (_scenario, readCSV, csv, code) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(readCSV()).rejects.toMatchObject({ code });
    });
});

describe("CSV validation before reconciliation", () => {
    test.each([
        {
            scenario: "missing contract headers",
            chainCSV:
                "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
            contractCSV: "Chain,Address,isFactory\n",
            error: {
                diagnostic: {
                    code: "MISSING_SHEET_HEADERS",
                    context: { missingHeaders: ["Status"] },
                },
            },
        },
        {
            scenario: "missing chain metadata headers",
            chainCSV: "Name,Chain Id\n",
            contractCSV: "Status,Chain,Address,isFactory\n",
            error: {
                diagnostic: {
                    code: "MISSING_SHEET_HEADERS",
                    context: { missingHeaders: ["Asset Recovery Address"] },
                },
            },
        },
        {
            scenario: "malformed contracts CSV",
            chainCSV:
                "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
            contractCSV:
                'Status,Chain,Address,isFactory\n"INACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n',
            error: { code: "CSV_QUOTE_NOT_CLOSED" },
        },
        {
            scenario: "malformed chain metadata CSV",
            chainCSV:
                'Name,Chain Id,Asset Recovery Address\n"ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n',
            contractCSV: "Status,Chain,Address,isFactory\n",
            error: { code: "CSV_QUOTE_NOT_CLOSED" },
        },
    ])(
        "rejects $scenario without encoding removals",
        async ({ chainCSV, contractCSV, error }) => {
            fetch
                .mockResolvedValueOnce(csvResponse(chainCSV))
                .mockResolvedValueOnce(csvResponse(contractCSV));
            getDetails.mockResolvedValue({ chains: [] });
            const encode = vi.spyOn(Interface.prototype, "encodeFunctionData");

            await expect(
                reconcile({
                    getAgreementState: createAgreementReader({ provider }),
                    getSheetState,
                    getSheetChainDetails,
                }),
            ).rejects.toMatchObject(error);
            expect(encode).not.toHaveBeenCalled();
        },
    );

    test.each([
        ["isFactory headers only", "Status,Chain,Address,isFactory\n"],
        ["IsFactory headers only", "Status,Chain,Address,IsFactory\n"],
        [
            "no active records",
            "Status,Chain,Address,isFactory\nINACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        ],
    ])(
        "preserves intentional chain removal for %s",
        async (_scenario, contractCSV) => {
            fetch
                .mockResolvedValueOnce(
                    csvResponse(
                        "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
                    ),
                )
                .mockResolvedValueOnce(csvResponse(contractCSV));
            getDetails.mockResolvedValue({
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
            });

            const result = await reconcile({
                getAgreementState: createAgreementReader({ provider }),
                getSheetState,
                getSheetChainDetails,
            });

            expect(result.validationWarnings).toEqual([]);
            expect(result.changes).toEqual([
                {
                    fn: "removeChains",
                    args: [["eip155:1"]],
                },
            ]);
            expect(result).not.toHaveProperty("solidityCode");
        },
    );
});
