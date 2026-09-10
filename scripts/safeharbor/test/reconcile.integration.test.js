import { Contract, Interface } from "ethers";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { dedent } from "../src/utils/dedent.js";
import { reconcile } from "../src/reconciliation/index.js";
import { createAgreementReader } from "../src/agreement/index.js";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

const provider = {};
const getDetails = vi.fn();
let encodeSpy;

beforeEach(() => {
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi
            .fn()
            .mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });
    vi.stubGlobal("fetch", vi.fn());
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(console, "error").mockImplementation(() => {});
    encodeSpy = vi.spyOn(Interface.prototype, "encodeFunctionData");
});

afterEach(() => {
    try {
        expect(encodeSpy).not.toHaveBeenCalled();
        expect(console.log).not.toHaveBeenCalled();
        expect(console.warn).not.toHaveBeenCalled();
        expect(console.error).not.toHaveBeenCalled();
    } finally {
        vi.unstubAllGlobals();
        vi.restoreAllMocks();
        vi.resetAllMocks();
    }
});

function csvResponse(csv) {
    return new Response(csv, { headers: { "content-type": "text/csv" } });
}

async function reconcileFrom({ chainCSV, contractCSV, details }) {
    fetch
        .mockResolvedValueOnce(csvResponse(chainCSV))
        .mockResolvedValueOnce(csvResponse(contractCSV));
    getDetails.mockResolvedValue(details);
    const report = await reconcile({
        getAgreementState: createAgreementReader(provider),
        getSheetState,
        getSheetChainDetails,
    });
    expect(getDetails).toHaveBeenCalledExactlyOnceWith();
    return report;
}

test.each([
    {
        scenario: "removal of a chain whose name matches a prototype property",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            __proto__,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [["A", 0n]],
                },
            ],
        },
        expected: {
            sheetChainDetails: {
                caip2ChainId: { ["__proto__"]: "eip155:1" },
                assetRecoveryAddress: {
                    ["__proto__"]: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "__proto__" },
            },
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [{ accountAddress: "A", childContractScope: 0n }],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {},
            changes: [{ fn: "removeChains", args: [["eip155:1"]] }],
            validationWarnings: [],
        },
    },
    {
        scenario: "clean reconciliation with raw bigint scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
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
        expected: {
            sheetChainDetails: {
                caip2ChainId: { ETHEREUM: "eip155:1" },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: { "eip155:1": "ETHEREUM" },
            },
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {
                "eip155:1": [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
            },
            changes: [],
            validationWarnings: [],
        },
    },
    {
        scenario: "blocked planning with normalized source data",
        chainCSV: "Name,Chain Id,Asset Recovery Address\n",
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expected: {
            sheetChainDetails: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            agreementOnChainState: {},
            sheetState: {},
            changes: [],
            validationWarnings: [
                { code: "UNKNOWN_SHEET_CHAIN", context: { chainName: "BASE" } },
            ],
        },
    },
])(
    "returns $scenario without encoding or reporting",
    async ({ chainCSV, contractCSV, details, expected }) => {
        expect(await reconcileFrom({ chainCSV, contractCSV, details })).toEqual(
            expected,
        );
    },
);

test.each([
    {
        scenario: "a renamed Sheet label preserves the same chain identity",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            RENAMED,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,RENAMED,0x2000000000000000000000000000000000000001,FALSE
        `,
        expectedChanges: [],
        expectedWarnings: [],
    },
    {
        scenario: "a reused Sheet label with another ID replaces the chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:8453,0x1000000000000000000000000000000000000001
            OLD,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        expectedChanges: [
            { fn: "removeChains", args: [["eip155:1"]] },
            {
                fn: "addChains",
                args: [
                    [
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                {
                                    accountAddress:
                                        "0x2000000000000000000000000000000000000001",
                                    childContractScope: 0,
                                },
                            ],
                        },
                    ],
                ],
            },
        ],
        expectedWarnings: [],
    },
    {
        scenario: "a reused label cannot hide an old ID missing from metadata",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:8453,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        expectedChanges: [],
        expectedWarnings: [
            {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:1" },
            },
        ],
    },
])(
    "$scenario",
    async ({ chainCSV, contractCSV, expectedChanges, expectedWarnings }) => {
        const result = await reconcileFrom({
            chainCSV,
            contractCSV,
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
        });
        expect(result.changes).toEqual(expectedChanges);
        expect(result.validationWarnings).toEqual(expectedWarnings);
    },
);

test.each(["__proto__", "constructor", "toString"])(
    "does not treat inherited metadata property %s as a known on-chain ID",
    async (chainId) => {
        const result = await reconcileFrom({
            chainCSV: "Name,Chain Id,Asset Recovery Address\n",
            contractCSV: "Status,Chain,Address,isFactory\n",
            details: {
                chains: [
                    {
                        caip2ChainId: chainId,
                        assetRecoveryAddress: "recovery",
                        accounts: [["A", 0n]],
                    },
                ],
            },
        });
        expect(result.agreementOnChainState).toEqual({
            [chainId]: {
                assetRecoveryAddress: "recovery",
                accounts: [{ accountAddress: "A", childContractScope: 0n }],
            },
        });
        expect(result.changes).toEqual([]);
        expect(result.validationWarnings).toEqual([
            { code: "UNKNOWN_ONCHAIN_CHAIN", context: { chainId } },
        ]);
    },
);

describe("validation warnings", () => {
    test.each([
        {
            scenario: "an addition on an existing chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,A,FALSE
                ACTIVE,ETHEREUM,,FALSE
            `,
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [["A", 0n]],
                    },
                ],
            },
        },
        {
            scenario: "a full replacement on an existing chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,,TRUE
            `,
            details: {
                chains: [
                    {
                        caip2ChainId: "eip155:1",
                        assetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                        accounts: [["A", 0n]],
                    },
                ],
            },
        },
        {
            scenario: "a new chain",
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,,FALSE
            `,
            details: { chains: [] },
        },
    ])(
        "blocks an empty address for $scenario before encoding",
        async ({ contractCSV, details }) => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                `,
                contractCSV,
                details,
            });
            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                {
                    code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                    context: { chainName: "ETHEREUM" },
                },
            ]);
        },
    );

    describe("Chain Property Validation", () => {
        test("should block account planning on a recovery mismatch", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });

        test("should return a diagnostic only for the mismatched recovery address", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);

            expect(result.validationWarnings).toEqual([
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });

        test("should collect unknown Safeharbor Sheet chains as validation warnings", async () => {
            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                    ACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.validationWarnings).toEqual([
                {
                    code: "UNKNOWN_SHEET_CHAIN",
                    context: { chainName: "UNKNOWN" },
                },
            ]);
            expect(result.changes).toEqual([]);
        });
    });

    describe("Chain Details Duplicate Validation", () => {
        test("should collect chain metadata warnings in the reconciliation result", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                    ETHEREUM,eip155:2,0x1000000000000000000000000000000000000001
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,BASE,0x3000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000001,FALSE
                    ACTIVE,ARBITRUM,0x4000000000000000000000000000000000000002,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000002",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:8453",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000002",
                            accounts: [
                                [
                                    "0x3000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:42161",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000003",
                            accounts: [
                                [
                                    "0x4000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x4000000000000000000000000000000000000002",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.validationWarnings).toEqual([duplicateWarning]);
            expect(result.changes).toEqual([]);
        });
    });

    describe("Validation warning aggregation", () => {
        test("retains unknown on-chain state while blocking planning", async () => {
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:137",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x6000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([unknownChainWarning]);
            expect(result.agreementOnChainState).toEqual({
                "eip155:137": {
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                    accounts: [
                        {
                            accountAddress:
                                "0x6000000000000000000000000000000000000001",
                            childContractScope: 0n,
                        },
                    ],
                },
            });
        });

        test("should collect warnings from every stage before planning updates", async () => {
            const duplicateWarning = {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            };
            const unknownChainWarning = {
                code: "UNKNOWN_ONCHAIN_CHAIN",
                context: { chainId: "eip155:137" },
            };

            const result = await reconcileFrom({
                chainCSV: dedent`
                    Name,Chain Id,Asset Recovery Address
                    ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                    BASE,eip155:8453,0x1000000000000000000000000000000000000002
                    ARBITRUM,eip155:42161,0x1000000000000000000000000000000000000003
                    OPTIMISM,eip155:10,0x1000000000000000000000000000000000000004
                    SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
                    ETHEREUM,eip155:2,0x1000000000000000000000000000000000000001
                `,
                contractCSV: dedent`
                    Status,Chain,Address,isFactory
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
                    ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
                    ACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE
                `,
                details: {
                    chains: [
                        {
                            caip2ChainId: "eip155:1",
                            assetRecoveryAddress:
                                "0x10000000000000000000000000000000000000ff",
                            accounts: [
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    2n,
                                ],
                            ],
                        },
                        {
                            caip2ChainId: "eip155:137",
                            assetRecoveryAddress:
                                "0x1000000000000000000000000000000000000001",
                            accounts: [
                                [
                                    "0x6000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });

            expect(result.changes).toEqual([]);
            expect(result.validationWarnings).toEqual([
                duplicateWarning,
                unknownChainWarning,
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "eip155:1",
                        address: "0x2000000000000000000000000000000000000001",
                        firstScope: 0n,
                        duplicateScope: 2n,
                    },
                },
                {
                    code: "UNKNOWN_SHEET_CHAIN",
                    context: { chainName: "UNKNOWN" },
                },
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x10000000000000000000000000000000000000ff",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ]);
        });
    });
});

test.each([
    {
        scenario:
            "an existing ETHEREUM chain with an undefined recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: undefined,
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing ETHEREUM chain with an null recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: null,
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing ETHEREUM chain with an empty recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an undefined recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: undefined,
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an null recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: null,
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario: "an existing SOLANA chain with an empty recovery address",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress: "",
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "MISSING_ONCHAIN_RECOVERY_ADDRESS",
                context: { chainName: "SOLANA" },
            },
        ],
    },
    {
        scenario:
            "independent metadata and empty-account warnings before diffing",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            ETHEREUM,eip155:2,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            },
            {
                code: "MISSING_SHEET_ACCOUNT_ADDRESS",
                context: { chainName: "ETHEREUM" },
            },
        ],
    },
    {
        scenario: "a malformed recovery address on a new EVM chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,not-an-address
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "ETHEREUM",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress: "not-an-address",
                },
            },
        ],
    },
    {
        scenario: "an invalid recovery checksum on a new EVM chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x8Ba1f109551bD432803012645Ac136ddd64DBA72
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INVALID_EVM_RECOVERY_ADDRESS",
                context: {
                    chainName: "ETHEREUM",
                    isNewChain: true,
                    onChainRecoveryAddress: undefined,
                    sheetRecoveryAddress:
                        "0x8Ba1f109551bD432803012645Ac136ddd64DBA72",
                },
            },
        ],
    },
    {
        scenario: "a Solana recovery-address case mismatch",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            SOLANA,solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp,29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,SOLANA,So11111111111111111111111111111111111111112,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
                    assetRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    accounts: [
                        ["So11111111111111111111111111111111111111112", 0n],
                    ],
                },
            ],
        },
        expectedWarnings: [
            {
                code: "RECOVERY_ADDRESS_MISMATCH",
                context: {
                    chainName: "SOLANA",
                    onChainRecoveryAddress:
                        "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                    sheetRecoveryAddress:
                        "29d2s7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2",
                },
            },
        ],
    },
    {
        scenario:
            "incomplete unused metadata with an otherwise valid chain removal",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            BASE,eip155:8453,
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
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
            {
                code: "INCOMPLETE_CHAIN_METADATA",
                context: {
                    chainName: "BASE",
                    chainId: "eip155:8453",
                    missingFields: ["Asset Recovery Address"],
                },
            },
        ],
    },
    {
        scenario: "multiple incomplete rows without otherwise required updates",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            BASE,eip155:8453,
            ,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "INCOMPLETE_CHAIN_METADATA",
                context: {
                    chainName: "BASE",
                    chainId: "eip155:8453",
                    missingFields: ["Asset Recovery Address"],
                },
            },
            {
                code: "INCOMPLETE_CHAIN_METADATA",
                context: {
                    chainName: "",
                    chainId: "eip155:1",
                    missingFields: ["Name"],
                },
            },
        ],
    },
    {
        scenario: "duplicate chain names",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            ETHEREUM,eip155:2,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
            {
                code: "DUPLICATE_CHAIN_NAME",
                context: {
                    chainName: "ETHEREUM",
                    firstChainId: "eip155:1",
                    duplicateChainId: "eip155:2",
                },
            },
        ],
    },
    {
        scenario: "duplicate chain IDs",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            OTHER,eip155:1,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
            {
                code: "DUPLICATE_CHAIN_ID",
                context: {
                    chainId: "eip155:1",
                    firstChainName: "ETHEREUM",
                    duplicateChainName: "OTHER",
                },
            },
        ],
    },
    {
        scenario: "duplicate additions to an existing chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
        `,
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
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0,
                    duplicateScope: 0,
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in a new chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
        expectedWarnings: [
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 0,
                },
            },
        ],
    },
    {
        scenario: "conflicting desired scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
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
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 2,
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts with no other differences",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
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
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainId: "eip155:1",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 0n,
                },
            },
        ],
    },
    {
        scenario: "conflicting current scopes",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
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
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainId: "eip155:1",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 2n,
                },
            },
        ],
    },
    {
        scenario: "duplicate current accounts on a removed chain",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
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
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainId: "eip155:1",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0n,
                    duplicateScope: 0n,
                },
            },
        ],
    },
    {
        scenario: "duplicate accounts in both sources",
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,TRUE
        `,
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
            {
                code: "DUPLICATE_ONCHAIN_ACCOUNT",
                context: {
                    chainId: "eip155:1",
                    address: "0x2000000000000000000000000000000000000002",
                    firstScope: 0n,
                    duplicateScope: 2n,
                },
            },
            {
                code: "DUPLICATE_SHEET_ACCOUNT",
                context: {
                    chainName: "ETHEREUM",
                    address: "0x2000000000000000000000000000000000000001",
                    firstScope: 0,
                    duplicateScope: 2,
                },
            },
        ],
    },
])(
    "returns diagnostics only for $scenario",
    async ({ chainCSV, contractCSV, details, expectedWarnings }) => {
        const result = await reconcileFrom({ chainCSV, contractCSV, details });
        expect(result.changes).toEqual([]);
        expect(result.validationWarnings).toEqual(expectedWarnings);
    },
);

describe("CSV validation before reconciliation", () => {
    test.each([
        {
            scenario: "a repeated Status header hiding an active account",
            chainCSV: dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            `,
            contractCSV: dedent`
                Status,Chain,Address,isFactory,Status
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE,INACTIVE
            `,
            error: {
                diagnostic: {
                    code: "DUPLICATE_SHEET_HEADERS",
                    context: { duplicateHeaders: ["Status"] },
                },
            },
        },
        {
            scenario: "missing contract headers",
            chainCSV: dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            `,
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
            chainCSV: dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            `,
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                "INACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            `,
            error: { code: "CSV_QUOTE_NOT_CLOSED" },
        },
        {
            scenario: "malformed chain metadata CSV",
            chainCSV: dedent`
                Name,Chain Id,Asset Recovery Address
                "ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            `,
            contractCSV: "Status,Chain,Address,isFactory\n",
            error: { code: "CSV_QUOTE_NOT_CLOSED" },
        },
    ])("rejects $scenario", async ({ chainCSV, contractCSV, error }) => {
        fetch
            .mockResolvedValueOnce(csvResponse(chainCSV))
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

        await expect(
            reconcile({
                getAgreementState: createAgreementReader(provider),
                getSheetState,
                getSheetChainDetails,
            }),
        ).rejects.toMatchObject(error);
    });

    test.each([
        ["isFactory headers only", "Status,Chain,Address,isFactory\n"],
        ["IsFactory headers only", "Status,Chain,Address,IsFactory\n"],
        [
            "no active records",
            dedent`
                Status,Chain,Address,isFactory
                INACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            `,
        ],
    ])(
        "preserves intentional chain removal for %s",
        async (_scenario, contractCSV) => {
            fetch
                .mockResolvedValueOnce(
                    csvResponse(
                        dedent`
                            Name,Chain Id,Asset Recovery Address
                            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                        `,
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
                getAgreementState: createAgreementReader(provider),
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
