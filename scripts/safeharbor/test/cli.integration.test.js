import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { Contract, JsonRpcProvider } from "ethers";
import { main } from "../src/cli/index.js";
import {
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "../src/sheet/index.js";

vi.mock("ethers", async (importOriginal) => ({
    ...(await importOriginal()),
    Contract: vi.fn(),
    JsonRpcProvider: vi.fn(),
}));

let getDetails;
let argv;
let provider;
let stdout;
let stderr;
let warnings;

beforeEach(() => {
    getDetails = vi.fn();
    argv = process.argv;
    vi.stubEnv("ETH_RPC_URL", "https://rpc.example");
    provider = { destroy: vi.fn() };
    JsonRpcProvider.mockReturnValue(provider);
    Contract.mockReturnValueOnce({
        "getAddress(bytes32)": vi
            .fn()
            .mockResolvedValue("0x7000000000000000000000000000000000000001"),
    }).mockReturnValueOnce({ getDetails });
    vi.stubGlobal("fetch", vi.fn());
    stdout = vi.spyOn(console, "log").mockImplementation(() => {});
    stderr = vi.spyOn(console, "error").mockImplementation(() => {});
    warnings = vi.spyOn(console, "warn").mockImplementation(() => {});
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
        .mockResolvedValueOnce(
            new Response(chainCSV, { headers: { "content-type": "text/csv" } }),
        )
        .mockResolvedValueOnce(
            new Response(contractCSV, {
                headers: { "content-type": "text/csv" },
            }),
        );
    getDetails.mockResolvedValue(details);
}

describe.each([
    {
        scenario: "clean reconciliation",
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
                    ],
                },
            ],
        },
        solidityCode: "",
        report: {
            chainDetails: {
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
            onChainState: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {
                ETHEREUM: [
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
        warningMessages: [],
        exitCodes: { generate: 0, inspect: 0, verify: 0 },
        generateMessage: "No updates to generate",
        verifyMessage:
            "SafeHarbor verification passed: no updates or validation warnings.",
    },
    {
        scenario: "valid chain removal",
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
                    ],
                },
            ],
        },
        solidityCode:
            "bytes[] memory calldatas = new bytes[](1);\n\n// Remove chains: eip155:1\ncalldatas[0] = hex'1e12ef2900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000';\n\n_updateSafeHarbor(calldatas);",
        report: {
            chainDetails: {
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
            onChainState: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            sheetState: {},
            changes: [
                {
                    fn: "removeChains",
                    args: [["eip155:1"]],
                },
            ],
            validationWarnings: [],
        },
        warningMessages: [],
        exitCodes: { generate: 0, inspect: 0, verify: 2 },
        generateMessage: "Payload generation completed successfully.",
        verifyMessage:
            "SafeHarbor verification failed: 1 update(s), 0 validation warning(s).",
    },
    {
        scenario: "a warning without account differences",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,FALSE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        solidityCode: "",
        report: {
            chainDetails: {
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
            onChainState: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                },
            },
            sheetState: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000001",
                        childContractScope: 0,
                    },
                ],
            },
            changes: null,
            validationWarnings: [
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ],
        },
        warningMessages: [
            "Asset Recovery Address mismatch for chain 'ETHEREUM'.\nOn-chain: 0x1000000000000000000000000000000000000002\nSafeharbor Sheet: 0x1000000000000000000000000000000000000001",
        ],
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "Payload generation blocked: 1 validation warning(s).",
        verifyMessage:
            "SafeHarbor verification failed: 0 update(s), 1 validation warning(s).",
    },
    {
        scenario: "multiple warnings blocking account changes",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            "Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,FALSE\nACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRUE\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:1",
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
                },
            ],
        },
        solidityCode: "",
        report: {
            chainDetails: {
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
            onChainState: {
                ETHEREUM: {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: "0",
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000002",
                },
            },
            sheetState: {
                ETHEREUM: [
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 0,
                    },
                    {
                        accountAddress:
                            "0x2000000000000000000000000000000000000002",
                        childContractScope: 2,
                    },
                ],
            },
            changes: null,
            validationWarnings: [
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onChainRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
                {
                    code: "DUPLICATE_SHEET_ACCOUNT",
                    context: {
                        chainName: "ETHEREUM",
                        address: "0x2000000000000000000000000000000000000002",
                    },
                },
            ],
        },
        warningMessages: [
            "Asset Recovery Address mismatch for chain 'ETHEREUM'.\nOn-chain: 0x1000000000000000000000000000000000000002\nSafeharbor Sheet: 0x1000000000000000000000000000000000000001",
            "Duplicate account address in Safeharbor Sheet for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
        ],
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "Payload generation blocked: 2 validation warning(s).",
        verifyMessage:
            "SafeHarbor verification failed: 0 update(s), 2 validation warning(s).",
    },
])("$scenario", (fixture) => {
    test.each(["generate", "inspect", "verify"])(
        "%s uses the real pipeline",
        async (command) => {
            mockSources(fixture);

            expect(await runCli(command)).toBe(fixture.exitCodes[command]);
            expect(fetch.mock.calls).toEqual([
                [CHAIN_DETAILS_SHEET_URL],
                [CONTRACTS_IN_SCOPE_SHEET_URL],
            ]);
            expect(getDetails).toHaveBeenCalledExactlyOnceWith();
            expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
            expect(stderr).not.toHaveBeenCalled();

            if (command === "inspect") {
                expect(stdout.mock.calls).toEqual([
                    [JSON.stringify(fixture.report, null, 2)],
                ]);
            } else if (command === "verify") {
                expect(stdout.mock.calls).toEqual([[fixture.verifyMessage]]);
            } else {
                expect(stdout.mock.calls).toEqual(
                    fixture.solidityCode ? [[fixture.solidityCode]] : [],
                );
                expect(warnings).toHaveBeenLastCalledWith(
                    fixture.generateMessage,
                );
            }

            const expectedWarnings = fixture.warningMessages.map((message) => [
                message,
            ]);
            if (command === "generate")
                expectedWarnings.push([fixture.generateMessage]);
            expect(warnings.mock.calls).toEqual(expectedWarnings);
            if (fixture.report.validationWarnings.length > 0) {
                expect(warnings).not.toHaveBeenCalledWith(
                    "Payload generation completed successfully.",
                );
                expect(warnings).not.toHaveBeenCalledWith(
                    "No updates to generate",
                );
            }
        },
    );
});

describe.each([
    {
        scenario: "missing contracts headers",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV: "State,Network,Contract,Factory\n",
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
        errorMessage:
            "Missing required CSV headers: Status, Chain, Address, isFactory",
    },
    {
        scenario: "malformed contracts CSV",
        chainCSV:
            "Name,Chain Id,Asset Recovery Address\nETHEREUM,eip155:1,0x1000000000000000000000000000000000000001\n",
        contractCSV:
            'Status,Chain,Address,isFactory\nACTIVE,ETHEREUM,"unterminated,FALSE\n',
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
        errorMessage:
            "Quote Not Closed: the parsing is finished with an opening quote at line 2",
    },
])("$scenario", (fixture) => {
    test.each(["generate", "inspect", "verify"])(
        "%s exits 1 without output",
        async (command) => {
            mockSources(fixture);

            expect(await runCli(command)).toBe(1);
            expect(stdout).not.toHaveBeenCalled();
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                fixture.errorMessage,
            );
            expect(getDetails).not.toHaveBeenCalled();
            expect(warnings).not.toHaveBeenCalledWith("Generating updates...");
            expect(warnings).not.toHaveBeenCalledWith(
                "Payload generation completed successfully.",
            );
            expect(warnings).not.toHaveBeenCalledWith("No updates to generate");
        },
    );
});

describe.each(["generate", "inspect", "verify"])(
    "%s operational errors",
    (command) => {
        test("exits 1 when CSV fetching fails", async () => {
            const failure = new Error("CSV unavailable");
            fetch.mockRejectedValue(failure);

            expect(await runCli(command)).toBe(1);
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                "CSV unavailable",
            );
            expect(stdout).not.toHaveBeenCalled();
            expect(getDetails).not.toHaveBeenCalled();
        });

        test("exits 1 when fetching Agreement details fails", async () => {
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
            getDetails.mockRejectedValue(failure);

            expect(await runCli(command)).toBe(1);
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                "Agreement state unavailable",
            );
            expect(stdout).not.toHaveBeenCalled();
        });
    },
);
