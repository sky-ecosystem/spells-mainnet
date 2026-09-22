import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { Contract, Interface } from "ethers";
import { createAgreementReader } from "../src/agreement/index.js";
import { reconcile } from "../src/reconciliation/index.js";
import { getSheetChainDetails, getSheetState } from "../src/sheet/index.js";
import { dedent } from "../src/utils/dedent.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
}));

const provider = {};
let agreementInstance;
let chainValidatorInstance;
let encodeSpy;

beforeEach(() => {
    const chainlogInstance = {
        "getAddress(bytes32)": vi.fn().mockResolvedValue("0x7000000000000000000000000000000000000001"),
    };
    agreementInstance = {
        getDetails: vi.fn(),
        getChainValidator: vi.fn().mockResolvedValue("0x8000000000000000000000000000000000000001"),
    };
    chainValidatorInstance = { isChainValid: vi.fn().mockResolvedValue(true) };
    Contract.mockImplementationOnce(function Contract() {
        return chainlogInstance;
    })
        .mockImplementationOnce(function Contract() {
            return agreementInstance;
        })
        .mockImplementation(function Contract() {
            return chainValidatorInstance;
        });
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
    fetch.mockResolvedValueOnce(csvResponse(chainCSV)).mockResolvedValueOnce(csvResponse(contractCSV));
    agreementInstance.getDetails.mockResolvedValue(details);
    const report = await reconcile({
        getAgreementState: createAgreementReader(provider),
        getSheetState,
        getSheetChainDetails,
    });
    expect(agreementInstance.getDetails).toHaveBeenCalledExactlyOnceWith();
    return report;
}

test("returns clean reconciliation with raw bigint scopes without encoding or reporting", async () => {
    expect(
        await reconcileFrom({
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
                        assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                        accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                    },
                ],
            },
        }),
    ).toEqual({
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
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 0n,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        sheetState: {
            "eip155:1": {
                accounts: [
                    {
                        accountAddress: "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
                assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
        changes: [],
        warnings: [],
    });
});

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
                            assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                            accounts: [
                                {
                                    accountAddress: "0x2000000000000000000000000000000000000001",
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
])("$scenario", async ({ chainCSV, contractCSV, expectedChanges, expectedWarnings }) => {
    const result = await reconcileFrom({
        chainCSV,
        contractCSV,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });
    expect(result.changes).toEqual(expectedChanges);
    expect(result.warnings).toEqual(expectedWarnings);
});

test("collects warnings from every stage before planning updates", async () => {
    chainValidatorInstance.isChainValid.mockResolvedValue(false);
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
            ETHEREUM,eip155:2,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000003,FALSE
            ACTIVE,UNKNOWN,0x6000000000000000000000000000000000000001,FALSE
            ACTIVE,BASE,0x4000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x10000000000000000000000000000000000000ff",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                        ["0x2000000000000000000000000000000000000001", 2n],
                    ],
                },
                {
                    caip2ChainId: "eip155:137",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x6000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });

    expect(result.changes).toEqual([]);
    expect(result.warnings).toEqual([
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
            code: "INVALID_CHAIN_ID",
            context: { chainId: "eip155:8453" },
        },
        {
            code: "UNKNOWN_SHEET_CHAIN",
            context: { chainName: "UNKNOWN" },
        },
        {
            code: "RECOVERY_ADDRESS_MISMATCH",
            context: {
                chainId: "eip155:1",
                onChainRecoveryAddress: "0x10000000000000000000000000000000000000ff",
                sheetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
    ]);
    expect(chainValidatorInstance.isChainValid).toHaveBeenCalledExactlyOnceWith("eip155:8453");
});

test("blocks changes on invalid source recoveries while retaining an unrelated mismatch", async () => {
    const result = await reconcileFrom({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,invalid-sheet-address
            BASE,eip155:8453,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
            ACTIVE,BASE,0x4000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "invalid-on-chain-address",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
                {
                    caip2ChainId: "eip155:8453",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000003",
                    accounts: [["0x4000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });

    expect(result.changes).toStrictEqual([]);
    expect(result.warnings).toStrictEqual([
        {
            code: "INVALID_SHEET_RECOVERY_ADDRESS",
            context: {
                chainName: "ETHEREUM",
                chainId: "eip155:1",
                address: "invalid-sheet-address",
            },
        },
        {
            code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:1",
                address: "invalid-on-chain-address",
            },
        },
        {
            code: "RECOVERY_ADDRESS_MISMATCH",
            context: {
                chainId: "eip155:8453",
                onChainRecoveryAddress: "0x1000000000000000000000000000000000000003",
                sheetRecoveryAddress: "0x1000000000000000000000000000000000000002",
            },
        },
    ]);
});

test("an invalid rejected metadata row does not hide the retained chain's mismatch", async () => {
    const result = await reconcileFrom({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            ETHEREUM,eip155:1,invalid-rejected-address
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });

    expect(result.changes).toStrictEqual([]);
    expect(result.warnings).toStrictEqual([
        {
            code: "DUPLICATE_CHAIN_NAME",
            context: {
                chainName: "ETHEREUM",
                firstChainId: "eip155:1",
                duplicateChainId: "eip155:1",
            },
        },
        {
            code: "DUPLICATE_CHAIN_ID",
            context: {
                chainId: "eip155:1",
                firstChainName: "ETHEREUM",
                duplicateChainName: "ETHEREUM",
            },
        },
        {
            code: "INVALID_SHEET_RECOVERY_ADDRESS",
            context: {
                chainName: "ETHEREUM",
                chainId: "eip155:1",
                address: "invalid-rejected-address",
            },
        },
        {
            code: "RECOVERY_ADDRESS_MISMATCH",
            context: {
                chainId: "eip155:1",
                onChainRecoveryAddress: "0x1000000000000000000000000000000000000002",
                sheetRecoveryAddress: "0x1000000000000000000000000000000000000001",
            },
        },
    ]);
});

test("blocks chain removal when metadata-only chain uses an unsupported namespace", async () => {
    const result = await reconcileFrom({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            UNUSED,cosmos:cosmoshub-4,RecoveryAddress
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });

    expect(result.changes).toStrictEqual([]);
    expect(result.warnings).toStrictEqual([
        {
            code: "UNSUPPORTED_SHEET_CHAIN_NAMESPACE",
            context: { chainName: "UNUSED", chainId: "cosmos:cosmoshub-4" },
        },
    ]);
    expect(chainValidatorInstance.isChainValid).not.toHaveBeenCalled();
});

test("preserves intentional chain removal for an empty desired state", async () => {
    const result = await reconcileFrom({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
    });

    expect(result.warnings).toEqual([]);
    expect(result.changes).toEqual([
        {
            fn: "removeChains",
            args: [["eip155:1"]],
        },
    ]);
    expect(result).not.toHaveProperty("solidityCode");
});

test("blocks planning for malformed Agreement recovery addresses on retained and removed chains", async () => {
    const result = await reconcileFrom({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            BASE,eip155:8453,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "invalid-ethereum-address",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
                {
                    caip2ChainId: "eip155:8453",
                    assetRecoveryAddress: "invalid-base-address",
                    accounts: [["0x2000000000000000000000000000000000000002", 0n]],
                },
            ],
        },
    });

    expect(result.changes).toStrictEqual([]);
    expect(result.warnings).toStrictEqual([
        {
            code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:1",
                address: "invalid-ethereum-address",
            },
        },
        {
            code: "INVALID_ONCHAIN_RECOVERY_ADDRESS",
            context: {
                chainId: "eip155:8453",
                address: "invalid-base-address",
            },
        },
    ]);
});
