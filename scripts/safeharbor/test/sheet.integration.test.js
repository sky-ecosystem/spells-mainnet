import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { Interface } from "ethers";
import {
    getChainDetailsFromSheet,
    getNormalizedContractsInScopeFromSheet,
} from "../src/sheet.js";
import { createPayloadGenerator } from "../src/generatePayload.js";

const getAgreementDetails = vi.fn();
const generatePayload = createPayloadGenerator({ getAgreementDetails });

beforeEach(() => {
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

        await expect(
            getChainDetailsFromSheet("https://example.test/chains.csv"),
        ).rejects.toMatchObject({ diagnostic });
    },
);

test("propagates fetch failures unchanged without reporting", async () => {
    const failure = new Error("Network unavailable");
    fetch.mockRejectedValue(failure);

    await expect(
        getChainDetailsFromSheet("https://example.test/chains.csv"),
    ).rejects.toBe(failure);
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

        await expect(
            getNormalizedContractsInScopeFromSheet(
                "https://example.test/contracts.csv",
            ),
        ).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_CSV_HEADERS",
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
            getNormalizedContractsInScopeFromSheet(
                "https://example.test/contracts.csv",
            ),
        ).resolves.toEqual({
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
        });
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

        await expect(
            getChainDetailsFromSheet("https://example.test/chains.csv"),
        ).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_CSV_HEADERS",
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

        await expect(
            getChainDetailsFromSheet("https://example.test/chains.csv"),
        ).resolves.toEqual({
            chainDetails: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            validationWarnings: [],
        });
    });

    test("accepts reordered, quoted headers and an extra column", async () => {
        fetch.mockResolvedValue(
            csvResponse(
                'Notes,"Asset Recovery Address",Name,Chain Id\n"reviewed, mainnet",0x1000000000000000000000000000000000000001,ETHEREUM,eip155:1\n',
            ),
        );

        await expect(
            getChainDetailsFromSheet("https://example.test/chains.csv"),
        ).resolves.toEqual({
            chainDetails: {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
            validationWarnings: [],
        });
    });
});

describe("malformed CSV", () => {
    test.each([
        [
            "contracts with a malformed header",
            getNormalizedContractsInScopeFromSheet,
            'Status,Chain,Address,"isFactory\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "contracts with an unterminated quote",
            getNormalizedContractsInScopeFromSheet,
            'Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,"0x2000000000000000000000000000000000000001,FALSE\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "contracts with too few fields",
            getNormalizedContractsInScopeFromSheet,
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "contracts with too many fields",
            getNormalizedContractsInScopeFromSheet,
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE,EXTRA\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "chain metadata with a malformed header",
            getChainDetailsFromSheet,
            'Name,Chain Id,"Asset Recovery Address\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "chain metadata with an unterminated quote",
            getChainDetailsFromSheet,
            'Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,"0x1000000000000000000000000000000000000001\n',
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "chain metadata with too few fields",
            getChainDetailsFromSheet,
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "chain metadata with too many fields",
            getChainDetailsFromSheet,
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001,EXTRA\n",
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
    ])("rejects %s", async (_scenario, readCSV, csv, code) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(
            readCSV("https://example.test/input.csv"),
        ).rejects.toMatchObject({ code });
    });
});

describe("CSV validation before payload generation", () => {
    test.each([
        {
            scenario: "missing contract headers",
            chainCSV:
                "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
            contractCSV: "Chain,Address,isFactory\n",
            error: {
                diagnostic: {
                    code: "MISSING_CSV_HEADERS",
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
                    code: "MISSING_CSV_HEADERS",
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
        "rejects $scenario before reading state or encoding removals",
        async ({ chainCSV, contractCSV, error }) => {
            fetch
                .mockResolvedValueOnce(csvResponse(chainCSV))
                .mockResolvedValueOnce(csvResponse(contractCSV));
            const encode = vi.spyOn(Interface.prototype, "encodeFunctionData");

            await expect(generatePayload()).rejects.toMatchObject(error);
            expect(getAgreementDetails).not.toHaveBeenCalled();
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
            getAgreementDetails.mockResolvedValue({
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

            const result = await generatePayload();

            expect(result.validationWarnings).toEqual([]);
            expect(result.updates).toEqual([
                {
                    function: "removeChains",
                    args: [["eip155:1"]],
                    calldata: expect.stringMatching(/^0x[0-9a-f]+$/),
                },
            ]);
            expect(result.solidityCode).toContain(
                result.updates[0].calldata.slice(2),
            );
        },
    );
});
