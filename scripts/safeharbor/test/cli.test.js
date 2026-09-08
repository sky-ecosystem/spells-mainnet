import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { runCommand } from "../src/cli.js";
import { createAgreementInstance } from "../src/utils/contractUtils.js";
import {
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "../src/constants.js";

vi.mock("../src/utils/contractUtils.js", () => ({
    createAgreementInstance: vi.fn(),
}));

let stdout;
let stderr;
let warnings;

beforeEach(() => {
    vi.stubEnv("ETH_RPC_URL", "https://rpc.example");
    vi.stubGlobal("fetch", vi.fn());
    stdout = vi.spyOn(console, "log").mockImplementation(() => {});
    stderr = vi.spyOn(console, "error").mockImplementation(() => {});
    warnings = vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetAllMocks();
    vi.restoreAllMocks();
});

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
    const getDetails = vi.fn().mockResolvedValue(details);
    createAgreementInstance.mockResolvedValue({ getDetails });
    return getDetails;
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
        result: { updates: [], solidityCode: "", validationWarnings: [] },
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
        result: {
            updates: [
                {
                    function: "removeChains",
                    args: [["eip155:1"]],
                    calldata:
                        "0x1e12ef2900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000",
                },
            ],
            solidityCode:
                "\n        bytes[] memory calldatas = new bytes[](1);\n\n        // Remove chains: eip155:1\n        calldatas[0] = hex'1e12ef2900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000';\n\n        _updateSafeHarbor(calldatas);",
            validationWarnings: [],
        },
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
        result: {
            updates: [],
            solidityCode: "",
            validationWarnings: [
                "Asset Recovery Address mismatch for chain 'ETHEREUM'.\nOn-chain: 0x1000000000000000000000000000000000000002\nCSV:      0x1000000000000000000000000000000000000001",
            ],
        },
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
        result: {
            updates: [],
            solidityCode: "",
            validationWarnings: [
                "Asset Recovery Address mismatch for chain 'ETHEREUM'.\nOn-chain: 0x1000000000000000000000000000000000000002\nCSV:      0x1000000000000000000000000000000000000001",
                "Duplicate account address in CSV state for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002",
            ],
        },
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "Payload generation blocked: 2 validation warning(s).",
        verifyMessage:
            "SafeHarbor verification failed: 0 update(s), 2 validation warning(s).",
    },
])("$scenario", (fixture) => {
    test.each(["generate", "inspect", "verify"])(
        "%s uses the real pipeline",
        async (command) => {
            const getDetails = mockSources(fixture);

            expect(await runCommand(command)).toBe(fixture.exitCodes[command]);
            expect(createAgreementInstance).toHaveBeenCalledExactlyOnceWith(
                "https://rpc.example",
            );
            expect(fetch.mock.calls).toEqual([
                [CHAIN_DETAILS_SHEET_URL],
                [CONTRACTS_IN_SCOPE_SHEET_URL],
            ]);
            expect(getDetails).toHaveBeenCalledOnce();
            expect(stderr).not.toHaveBeenCalled();

            if (command === "inspect") {
                expect(stdout.mock.calls).toEqual([
                    [JSON.stringify(fixture.result, null, 2)],
                ]);
            } else if (command === "verify") {
                expect(stdout.mock.calls).toEqual([[fixture.verifyMessage]]);
            } else {
                expect(stdout.mock.calls).toEqual(
                    fixture.result.solidityCode
                        ? [[fixture.result.solidityCode]]
                        : [],
                );
                expect(warnings).toHaveBeenLastCalledWith(
                    fixture.generateMessage,
                );
            }

            for (const warning of fixture.result.validationWarnings) {
                expect(warnings).toHaveBeenCalledWith(warning);
            }
            if (fixture.result.validationWarnings.length > 0) {
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
            const getDetails = mockSources(fixture);

            expect(await runCommand(command)).toBe(1);
            expect(stdout).not.toHaveBeenCalled();
            expect(stderr).toHaveBeenLastCalledWith(
                "Failed to execute command:",
                expect.objectContaining({ message: fixture.errorMessage }),
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

describe("command errors", () => {
    test.each([
        [undefined, "Error: Command is required"],
        ["unknown", "Error: Unknown command 'unknown'"],
    ])(
        "rejects command %s before accessing external data",
        async (command, message) => {
            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenCalledWith(message);
            expect(stdout).not.toHaveBeenCalled();
            expect(createAgreementInstance).not.toHaveBeenCalled();
            expect(fetch).not.toHaveBeenCalled();
        },
    );

    test("rejects a missing ETH_RPC_URL before accessing external data", async () => {
        vi.stubEnv("ETH_RPC_URL", "");

        expect(await runCommand("verify")).toBe(1);
        expect(stderr).toHaveBeenCalledWith(
            "Error: ETH_RPC_URL environment variable is not set.",
        );
        expect(stdout).not.toHaveBeenCalled();
        expect(createAgreementInstance).not.toHaveBeenCalled();
        expect(fetch).not.toHaveBeenCalled();
    });
});

describe.each(["generate", "inspect", "verify"])(
    "%s operational errors",
    (command) => {
        test("exits 1 when Agreement construction fails", async () => {
            const failure = new Error("RPC unavailable");
            createAgreementInstance.mockRejectedValue(failure);

            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenLastCalledWith(
                "Failed to execute command:",
                failure,
            );
            expect(stdout).not.toHaveBeenCalled();
            expect(fetch).not.toHaveBeenCalled();
        });

        test("exits 1 when CSV fetching fails", async () => {
            const getDetails = vi.fn();
            createAgreementInstance.mockResolvedValue({ getDetails });
            const failure = new Error("CSV unavailable");
            fetch.mockRejectedValue(failure);

            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenLastCalledWith(
                "Failed to execute command:",
                failure,
            );
            expect(stdout).not.toHaveBeenCalled();
            expect(getDetails).not.toHaveBeenCalled();
        });

        test("exits 1 when Agreement state reads fail", async () => {
            const getDetails = mockSources({
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
                                [
                                    "0x2000000000000000000000000000000000000001",
                                    0n,
                                ],
                            ],
                        },
                    ],
                },
            });
            const failure = new Error("Agreement state unavailable");
            getDetails.mockRejectedValue(failure);

            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenLastCalledWith(
                "Failed to execute command:",
                failure,
            );
            expect(stdout).not.toHaveBeenCalled();
        });
    },
);
