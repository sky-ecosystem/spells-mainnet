import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { Contract, Interface, JsonRpcProvider } from "ethers";
import { main } from "../src/cli/index.js";
import { dedent } from "../src/utils/dedent.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
    JsonRpcProvider: vi.fn(),
}));

let agreementInstance;
let argv;
let provider;
let stdout;
let stderr;
let warnings;
let encodeSpy;
let chainValidatorInstance;

beforeEach(() => {
    agreementInstance = {
        getDetails: vi.fn(),
        getChainValidator: vi.fn().mockResolvedValue("0x8000000000000000000000000000000000000001"),
    };
    argv = process.argv;
    vi.stubEnv("ETH_RPC_URL", "https://rpc.example");
    provider = { destroy: vi.fn() };
    JsonRpcProvider.mockImplementation(function JsonRpcProvider() {
        return provider;
    });
    const chainlogInstance = {
        "getAddress(bytes32)": vi.fn().mockResolvedValue("0x7000000000000000000000000000000000000001"),
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
    stdout = vi.spyOn(console, "log").mockImplementation(() => {});
    stderr = vi.spyOn(console, "error").mockImplementation(() => {});
    warnings = vi.spyOn(console, "warn").mockImplementation(() => {});
    encodeSpy = vi.spyOn(Interface.prototype, "encodeFunctionData");
});

afterEach(() => {
    process.argv = argv;
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetAllMocks();
    vi.restoreAllMocks();
});

async function runCli(command) {
    process.argv = ["node", "index.js", command];
    return main();
}

function mockSources({ chainCSV, contractCSV, details }) {
    fetch
        .mockResolvedValueOnce(new Response(chainCSV, { headers: { "content-type": "text/csv" } }))
        .mockResolvedValueOnce(
            new Response(contractCSV, {
                headers: { "content-type": "text/csv" },
            }),
        );
    agreementInstance.getDetails.mockResolvedValue(details);
}

test("blocks all generation when the configured validator rejects new chain IDs", async () => {
    mockSources({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
            UNKNOWN_EVM,eip155:999999,0x1000000000000000000000000000000000000002
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
            ACTIVE,UNKNOWN_EVM,0x2000000000000000000000000000000000000003,FALSE
        `,
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["A", 0n]],
                },
            ],
        },
    });
    chainValidatorInstance.isChainValid.mockResolvedValue(false);

    expect(await runCli("generate")).toBe(2);
    expect(chainValidatorInstance.isChainValid.mock.calls).toEqual([["eip155:999999"]]);
    expect(warnings.mock.calls).toEqual([
        ["⚠️ Chain ID 'eip155:999999' is not accepted by the Agreement's configured chain validator"],
        ["❌ Payload generation blocked: 1 validation warning(s)."],
    ]);
    expect(stdout).not.toHaveBeenCalled();
    expect(encodeSpy).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("blocks generation for an invalid Sheet account address", async () => {
    mockSources({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x52908400098527886E0F7030069857D2E4169Ee7,FALSE
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
    });

    expect(await runCli("generate")).toBe(2);
    expect(warnings.mock.calls).toEqual([
        [
            "⚠️ Invalid account address in SafeHarbor Sheet for chain 'ETHEREUM' (eip155:1): 0x52908400098527886E0F7030069857D2E4169Ee7",
        ],
        ["❌ Payload generation blocked: 1 validation warning(s)."],
    ]);
    expect(stdout).not.toHaveBeenCalled();
    expect(encodeSpy).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test.each(["generate", "inspect"])("%s reports a line terminator in an allowlisted Sheet chain ID", async (command) => {
    const chainId = "eip155:1\nrevert(); //";
    mockSources({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,"eip155:1
            revert(); //",0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
    });

    expect(await runCli(command)).toBe(command === "generate" ? 2 : 0);
    expect(chainValidatorInstance.isChainValid).toHaveBeenCalledExactlyOnceWith(chainId);
    expect(warnings.mock.calls[0]).toEqual([
        "⚠️ Line terminator in SafeHarbor Sheet Chain Id for 'ETHEREUM': \"eip155:1\\nrevert(); //\"",
    ]);
    if (command === "generate") {
        expect(stdout).not.toHaveBeenCalled();
        expect(warnings.mock.calls[1]).toEqual(["❌ Payload generation blocked: 1 validation warning(s)."]);
    } else {
        expect(JSON.parse(stdout.mock.calls[0][0])).toMatchObject({
            changes: [],
            warnings: [
                {
                    code: "SHEET_CHAIN_ID_LINE_TERMINATOR",
                    context: {
                        chainName: "ETHEREUM",
                        chainId,
                    },
                },
            ],
        });
    }
    expect(stderr).not.toHaveBeenCalled();
    expect(encodeSpy).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

test("validator RPC failure exits 1 and cleans up without generating output", async () => {
    mockSources({
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE
        `,
        details: { chains: [] },
    });
    chainValidatorInstance.isChainValid.mockRejectedValue(
        Object.assign(new Error("Validator unavailable"), {
            code: "NETWORK_ERROR",
        }),
    );

    expect(await runCli("generate")).toBe(1);
    expect(stderr).toHaveBeenCalledExactlyOnceWith(dedent`
        ❌ Failed to execute command:
               Source: Agreement state
               Validator unavailable
               Code: NETWORK_ERROR
    `);
    expect(stdout).not.toHaveBeenCalled();
    expect(warnings).not.toHaveBeenCalled();
    expect(encodeSpy).not.toHaveBeenCalled();
    expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
});

describe.each([
    {
        scenario: "clean reconciliation",
        commands: ["generate", "inspect", "verify"],
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
        solidityCode: "",
        report: {
            sheetChainDetails: {
                caip2ChainId: {
                    ETHEREUM: "eip155:1",
                },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: {
                    "eip155:1": "ETHEREUM",
                },
            },
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress: "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
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
        },
        warningMessages: [],
        exitCodes: { generate: 0, inspect: 0, verify: 0 },
        generateMessage: "✅ No updates to generate",
        verifyMessage: "✅ SafeHarbor verification passed: no updates or validation warnings.",
    },
    {
        scenario: "valid chain removal",
        commands: ["generate", "inspect", "verify"],
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
        solidityCode: dedent`
            bytes[] memory calldatas = new bytes[](1);

            // Remove chains: eip155:1
            calldatas[0] = hex'1e12ef2900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000';

            _updateSafeHarbor(calldatas);
        `,
        report: {
            sheetChainDetails: {
                caip2ChainId: {
                    ETHEREUM: "eip155:1",
                },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: {
                    "eip155:1": "ETHEREUM",
                },
            },
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress: "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {},
            changes: [
                {
                    fn: "removeChains",
                    args: [["eip155:1"]],
                },
            ],
            warnings: [],
        },
        warningMessages: [],
        exitCodes: { generate: 0, inspect: 0, verify: 2 },
        generateMessage: "✅ Payload generation completed successfully.",
        verifyMessage: "❌ SafeHarbor verification failed: 1 update(s), 0 validation warning(s).",
    },
    {
        scenario: "multiple warnings blocking account changes",
        commands: ["generate", "inspect", "verify"],
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE
            ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE
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
        solidityCode: "",
        report: {
            sheetChainDetails: {
                caip2ChainId: {
                    ETHEREUM: "eip155:1",
                },
                assetRecoveryAddress: {
                    ETHEREUM: "0x1000000000000000000000000000000000000001",
                },
                name: {
                    "eip155:1": "ETHEREUM",
                },
            },
            agreementOnChainState: {
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress: "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000002",
                },
            },
            sheetState: {
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress: "0x2000000000000000000000000000000000000002",
                            childContractScope: 0,
                        },
                        {
                            accountAddress: "0x2000000000000000000000000000000000000002",
                            childContractScope: 2,
                        },
                    ],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            },
            changes: [],
            warnings: [
                {
                    code: "DUPLICATE_SHEET_ACCOUNT",
                    context: {
                        chainName: "ETHEREUM",
                        address: "0x2000000000000000000000000000000000000002",
                        firstScope: 0,
                        duplicateScope: 2,
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
            ],
        },
        warningMessages: [
            "⚠️ Duplicate account address in Safeharbor Sheet for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002; first scope=0, duplicate scope=2",
            dedent`
                ⚠️ Asset Recovery Address mismatch for chain 'eip155:1'.
                       On-chain: 0x1000000000000000000000000000000000000002
                       Safeharbor Sheet: 0x1000000000000000000000000000000000000001
            `,
        ],
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "❌ Payload generation blocked: 2 validation warning(s).",
        verifyMessage: "❌ SafeHarbor verification failed: 0 update(s), 2 validation warning(s).",
    },
    {
        scenario: "unknown on-chain IDs and their duplicate accounts remain inspectable",
        commands: ["inspect"],
        chainCSV: "Name,Chain Id,Asset Recovery Address\n",
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:8453",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [
                        ["A", 0n],
                        ["A", 2n],
                    ],
                },
            ],
        },
        report: {
            sheetChainDetails: {
                caip2ChainId: {},
                assetRecoveryAddress: {},
                name: {},
            },
            agreementOnChainState: {
                "eip155:8453": {
                    accounts: [
                        { accountAddress: "A", childContractScope: "0" },
                        { accountAddress: "A", childContractScope: "2" },
                    ],
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {},
            changes: [],
            warnings: [
                {
                    code: "UNKNOWN_ONCHAIN_CHAIN",
                    context: { chainId: "eip155:8453" },
                },
                {
                    code: "DUPLICATE_ONCHAIN_ACCOUNT",
                    context: {
                        chainId: "eip155:8453",
                        address: "A",
                        firstScope: "0",
                        duplicateScope: "2",
                    },
                },
            ],
        },
        warningMessages: [
            dedent`
                ⚠️ Unknown chain in on-chain state: caip2ChainId='eip155:8453'.
                       Add this chain to the 'safe-harbor-asset-recovery' tab before keeping or removing it.
            `,
            "⚠️ Duplicate account address in on-chain state for chain 'eip155:8453': A; first scope=0, duplicate scope=2",
        ],
        exitCodes: { inspect: 0 },
    },
])("$scenario", (fixture) => {
    test.each(fixture.commands)("%s uses the real pipeline", async (command) => {
        mockSources(fixture);

        expect(await runCli(command)).toBe(fixture.exitCodes[command]);
        if (command !== "generate" || fixture.report.changes.length === 0) {
            expect(encodeSpy).not.toHaveBeenCalled();
        }
        expect(fetch).toHaveBeenCalledTimes(2);
        expect(agreementInstance.getDetails).toHaveBeenCalledExactlyOnceWith();
        expect(chainValidatorInstance.isChainValid).not.toHaveBeenCalled();
        expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
        expect(stderr).not.toHaveBeenCalled();

        if (command === "inspect") {
            expect(stdout.mock.calls).toEqual([[JSON.stringify(fixture.report, null, 2)]]);
        } else if (command === "verify") {
            expect(stdout.mock.calls).toEqual([[fixture.verifyMessage]]);
        } else {
            expect(stdout.mock.calls).toEqual(fixture.solidityCode ? [[fixture.solidityCode]] : []);
            expect(warnings).toHaveBeenLastCalledWith(fixture.generateMessage);
        }

        const expectedWarnings = fixture.warningMessages.map((message) => [message]);
        if (command === "generate") {
            expectedWarnings.push([fixture.generateMessage]);
        }
        expect(warnings.mock.calls).toEqual(expectedWarnings);
        if (fixture.report.warnings.length > 0) {
            expect(warnings).not.toHaveBeenCalledWith("✅ Payload generation completed successfully.");
            expect(warnings).not.toHaveBeenCalledWith("✅ No updates to generate");
        }
    });
});

describe.each([
    {
        scenario: "missing contracts headers",
        commands: ["generate"],
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: "State,Network,Contract,Factory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress: "0x1000000000000000000000000000000000000001",
                    accounts: [["0x2000000000000000000000000000000000000001", 0n]],
                },
            ],
        },
        errorMessage: dedent`
            ❌ Failed to execute command:
                   Source: Safeharbor Sheet contracts
                   Missing required CSV headers: Status, Chain, Address, isFactory
        `,
    },
    {
        scenario: "malformed contracts CSV",
        commands: ["inspect"],
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
        contractCSV: dedent`
            Status,Chain,Address,isFactory
            ACTIVE,ETHEREUM,"unterminated,FALSE
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
        errorMessage: dedent`
            ❌ Failed to execute command:
                   Source: Safeharbor Sheet contracts
                   Quote Not Closed: the parsing is finished with an opening quote at line 2
                   Code: CSV_QUOTE_NOT_CLOSED
        `,
    },
])("$scenario", (fixture) => {
    test.each(fixture.commands)("%s exits 1 without output", async (command) => {
        mockSources(fixture);

        expect(await runCli(command)).toBe(1);
        expect(stdout).not.toHaveBeenCalled();
        expect(stderr).toHaveBeenCalledExactlyOnceWith(fixture.errorMessage);
        expect(warnings).not.toHaveBeenCalledWith("Generating updates...");
        expect(warnings).not.toHaveBeenCalledWith("✅ Payload generation completed successfully.");
        expect(warnings).not.toHaveBeenCalledWith("✅ No updates to generate");
    });
});

test("verify exits 1 when fetching Agreement details fails", async () => {
    fetch
        .mockResolvedValueOnce(
            new Response("Name,Chain Id,Asset Recovery Address\n", {
                headers: { "content-type": "text/csv" },
            }),
        )
        .mockResolvedValueOnce(
            new Response("Status,Chain,Address,isFactory\n", {
                headers: { "content-type": "text/csv" },
            }),
        );
    const failure = new Error("Agreement state unavailable");
    agreementInstance.getDetails.mockRejectedValue(failure);

    expect(await runCli("verify")).toBe(1);
    expect(stderr).toHaveBeenCalledExactlyOnceWith(
        dedent`
            ❌ Failed to execute command:
                   Source: Agreement state
                   Agreement state unavailable
        `,
    );
    expect(stdout).not.toHaveBeenCalled();
});
