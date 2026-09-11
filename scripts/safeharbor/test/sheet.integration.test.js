import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { dedent } from "../src/utils/dedent.js";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";

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
    {
        status: 200,
        headers: { "content-type": "text/csv-extended" },
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

test("accepts CSV media type casing, whitespace and parameters", async () => {
    fetch.mockResolvedValue(
        new Response("Name,Chain Id,Asset Recovery Address\n", {
            headers: { "content-type": "TEXT/CSV ; charset=utf-8" },
        }),
    );
    await expect(getSheetChainDetails()).resolves.toEqual({
        value: { caip2ChainId: {}, assetRecoveryAddress: {}, name: {} },
        warnings: [],
    });
});

describe("contracts CSV headers", () => {
    test("rejects repeated headers before reading any records", async () => {
        fetch.mockResolvedValue(
            csvResponse("Status,Chain,Address,isFactory,Status\n"),
        );
        await expect(
            getSheetState({
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            }),
        ).rejects.toMatchObject({
            diagnostic: {
                code: "DUPLICATE_SHEET_HEADERS",
                context: { duplicateHeaders: ["Status"] },
            },
        });
    });

    test.each([
        [
            "Status in a header-only file",
            "Chain,Address,isFactory\n",
            ["Status"],
        ],
        [
            "Status with records",
            dedent`
                Chain,Address,isFactory
                ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            `,
            ["Status"],
        ],
        [
            "Chain in a header-only file",
            "Status,Address,isFactory\n",
            ["Chain"],
        ],
        [
            "Address in a header-only file",
            "Status,Chain,isFactory\n",
            ["Address"],
        ],
        [
            "factory flag in a header-only file",
            "Status,Chain,Address\n",
            ["isFactory"],
        ],
        [
            "all headers in an empty file",
            "",
            ["Status", "Chain", "Address", "isFactory"],
        ],
    ])("rejects missing %s", async (_scenario, csv, missingHeaders) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(getSheetState()).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: { missingHeaders },
            },
        });
    });

    test.each([
        [
            "isFactory",
            dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
                INACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,TRUE
            `,
        ],
        [
            "reordered, quoted headers and an extra column",
            dedent`
                Notes,"Address",IsFactory,Chain,Status
                "reviewed, factory",0x2000000000000000000000000000000000000001,TRUE,ETHEREUM,ACTIVE
                reviewed,0x2000000000000000000000000000000000000002,FALSE,ETHEREUM,ACTIVE
                old,0x2000000000000000000000000000000000000003,TRUE,ETHEREUM,INACTIVE
            `,
        ],
        [
            "both factory aliases without changing flag semantics",
            dedent`
                Status,Chain,Address,isFactory,IsFactory
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE,FALSE
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE,FALSE
                INACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE,TRUE
            `,
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
            warnings: [],
        });
        expect(fetch).toHaveBeenCalledExactlyOnceWith(
            "https://docs.google.com/spreadsheets/d/1e_KOYOeBGaA5EG3Xqco6lOP_a0zV4Vrm3w5-dqFk00U/export?format=csv&gid=1121763694",
        );
    });
});

describe("chain metadata CSV headers", () => {
    test("rejects repeated metadata headers", async () => {
        fetch.mockResolvedValue(
            csvResponse(dedent`
            Name,Name,Chain Id,Asset Recovery Address
            ETHEREUM,BASE,eip155:1,0x1000000000000000000000000000000000000001
        `),
        );
        await expect(getSheetChainDetails()).rejects.toMatchObject({
            diagnostic: {
                code: "DUPLICATE_SHEET_HEADERS",
                context: { duplicateHeaders: ["Name"] },
            },
        });
    });
    test.each([
        [
            "Name in a header-only file",
            "Chain Id,Asset Recovery Address\n",
            ["Name"],
        ],
        [
            "Name with records",
            dedent`
                Chain Id,Asset Recovery Address
                eip155:1,0x1000000000000000000000000000000000000001
            `,
            ["Name"],
        ],
        [
            "Chain Id in a header-only file",
            "Name,Asset Recovery Address\n",
            ["Chain Id"],
        ],
        [
            "Asset Recovery Address in a header-only file",
            "Name,Chain Id\n",
            ["Asset Recovery Address"],
        ],
        [
            "all headers in a blank file",
            "\n \n",
            ["Name", "Chain Id", "Asset Recovery Address"],
        ],
    ])("rejects missing %s", async (_scenario, csv, missingHeaders) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(getSheetChainDetails()).rejects.toMatchObject({
            diagnostic: {
                code: "MISSING_SHEET_HEADERS",
                context: { missingHeaders },
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
                dedent`
                    Notes,"Asset Recovery Address",Name,Chain Id
                    "reviewed, mainnet",0x1000000000000000000000000000000000000001,ETHEREUM,eip155:1
                `,
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
            "contracts with too few fields",
            getSheetState,
            dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001
            `,
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
        [
            "chain metadata with an unterminated quote",
            getSheetChainDetails,
            dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,"0x1000000000000000000000000000000000000001
            `,
            "CSV_QUOTE_NOT_CLOSED",
        ],
        [
            "chain metadata with too many fields",
            getSheetChainDetails,
            dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001,EXTRA
            `,
            "CSV_RECORD_INCONSISTENT_COLUMNS",
        ],
    ])("rejects %s", async (_scenario, readCSV, csv, code) => {
        fetch.mockResolvedValue(csvResponse(csv));

        await expect(readCSV()).rejects.toMatchObject({ code });
    });
});
