import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { createCommandRunner } from "../src/cli.js";
import { createPayloadGenerator } from "../src/generatePayload.js";
import {
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "../src/sheet.js";

let getAgreementDetails;
let runCommand;
let stdout;
let stderr;
let warnings;

beforeEach(() => {
    getAgreementDetails = vi.fn();
    const generatePayload = createPayloadGenerator({ getAgreementDetails });
    runCommand = createCommandRunner({ generatePayload });
    vi.stubGlobal("fetch", vi.fn());
    stdout = vi.spyOn(console, "log").mockImplementation(() => {});
    stderr = vi.spyOn(console, "error").mockImplementation(() => {});
    warnings = vi.spyOn(console, "warn").mockImplementation(() => {});
});

afterEach(() => {
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
    getAgreementDetails.mockResolvedValue(details);
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
                "bytes[] memory calldatas = new bytes[](1);\n\n// Remove chains: eip155:1\ncalldatas[0] = hex'1e12ef2900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000';\n\n_updateSafeHarbor(calldatas);",
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
        result: {
            updates: [],
            solidityCode: "",
            validationWarnings: [
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onchainRecoveryAddress:
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
        result: {
            updates: [],
            solidityCode: "",
            validationWarnings: [
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainName: "ETHEREUM",
                        onchainRecoveryAddress:
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

            expect(await runCommand(command)).toBe(fixture.exitCodes[command]);
            expect(fetch.mock.calls).toEqual([
                [CHAIN_DETAILS_SHEET_URL],
                [CONTRACTS_IN_SCOPE_SHEET_URL],
            ]);
            expect(getAgreementDetails).toHaveBeenCalledExactlyOnceWith();
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

            const expectedWarnings = fixture.warningMessages.map((message) => [
                message,
            ]);
            if (command === "generate")
                expectedWarnings.push([fixture.generateMessage]);
            expect(warnings.mock.calls).toEqual(expectedWarnings);
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
            mockSources(fixture);

            expect(await runCommand(command)).toBe(1);
            expect(stdout).not.toHaveBeenCalled();
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                fixture.errorMessage,
            );
            expect(getAgreementDetails).not.toHaveBeenCalled();
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

            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                "CSV unavailable",
            );
            expect(stdout).not.toHaveBeenCalled();
            expect(getAgreementDetails).not.toHaveBeenCalled();
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
            getAgreementDetails.mockRejectedValue(failure);

            expect(await runCommand(command)).toBe(1);
            expect(stderr).toHaveBeenCalledExactlyOnceWith(
                "Failed to execute command:",
                "Agreement state unavailable",
            );
            expect(stdout).not.toHaveBeenCalled();
        });
    },
);
