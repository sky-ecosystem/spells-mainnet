import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { Contract, Interface, JsonRpcProvider } from "ethers";
import { dedent } from "../src/utils/dedent.js";
import { main } from "../src/cli/index.js";

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
let encodeSpy;

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

test.each(["generate", "inspect", "verify"])(
    "%s blocks invalid factory flags on existing and new chains",
    async (command) => {
        mockSources({
            chainCSV: dedent`
                Name,Chain Id,Asset Recovery Address
                ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
                BASE,eip155:8453,0x1000000000000000000000000000000000000002
            `,
            contractCSV: dedent`
                Status,Chain,Address,isFactory
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000001,
                ACTIVE,ETHEREUM,0x2000000000000000000000000000000000000002,TRU
                ACTIVE,BASE,0x3000000000000000000000000000000000000001,true
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
        });

        expect(await runCli(command)).toBe(command === "inspect" ? 0 : 2);
        expect(provider.destroy).toHaveBeenCalledExactlyOnceWith();
        expect(stderr).not.toHaveBeenCalled();
        expect(warnings.mock.calls.slice(0, 2)).toEqual([
            [
                "Invalid factory flag in Safeharbor Sheet for chain 'ETHEREUM', account '0x2000000000000000000000000000000000000002': isFactory='TRU'; expected TRUE, FALSE, or blank",
            ],
            [
                "Invalid factory flag in Safeharbor Sheet for chain 'BASE', account '0x3000000000000000000000000000000000000001': isFactory='true'; expected TRUE, FALSE, or blank",
            ],
        ]);

        if (command === "inspect") {
            expect(JSON.parse(stdout.mock.calls[0][0])).toMatchObject({
                changes: [],
                validationWarnings: [
                    {
                        code: "INVALID_SHEET_FACTORY_FLAG",
                        context: {
                            chainName: "ETHEREUM",
                            address:
                                "0x2000000000000000000000000000000000000002",
                            column: "isFactory",
                            value: "TRU",
                        },
                    },
                    {
                        code: "INVALID_SHEET_FACTORY_FLAG",
                        context: {
                            chainName: "BASE",
                            address:
                                "0x3000000000000000000000000000000000000001",
                            column: "isFactory",
                            value: "true",
                        },
                    },
                ],
            });
            expect(warnings).toHaveBeenCalledTimes(2);
        } else if (command === "verify") {
            expect(stdout.mock.calls).toEqual([
                [
                    "SafeHarbor verification failed: 0 update(s), 2 validation warning(s).",
                ],
            ]);
            expect(warnings).toHaveBeenCalledTimes(2);
        } else {
            expect(stdout).not.toHaveBeenCalled();
            expect(warnings).toHaveBeenCalledTimes(3);
            expect(warnings).toHaveBeenLastCalledWith(
                "Payload generation blocked: 2 validation warning(s).",
            );
        }
    },
);

describe.each([
    {
        scenario: "clean reconciliation",
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
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
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
                    ],
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
                        "0x1000000000000000000000000000000000000002",
                    accounts: [
                        ["0x2000000000000000000000000000000000000001", 0n],
                    ],
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
                "eip155:1": {
                    accounts: [
                        {
                            accountAddress:
                                "0x2000000000000000000000000000000000000001",
                            childContractScope: 0,
                        },
                    ],
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            changes: [],
            validationWarnings: [
                {
                    code: "RECOVERY_ADDRESS_MISMATCH",
                    context: {
                        chainId: "eip155:1",
                        onChainRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ],
        },
        warningMessages: [
            dedent`
                Asset Recovery Address mismatch for chain 'eip155:1'.
                On-chain: 0x1000000000000000000000000000000000000002
                Safeharbor Sheet: 0x1000000000000000000000000000000000000001
            `,
        ],
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "Payload generation blocked: 1 validation warning(s).",
        verifyMessage:
            "SafeHarbor verification failed: 0 update(s), 1 validation warning(s).",
    },
    {
        scenario: "multiple warnings blocking account changes",
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
                "eip155:1": {
                    accounts: [
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
                    assetRecoveryAddress:
                        "0x1000000000000000000000000000000000000001",
                },
            },
            changes: [],
            validationWarnings: [
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
                        onChainRecoveryAddress:
                            "0x1000000000000000000000000000000000000002",
                        sheetRecoveryAddress:
                            "0x1000000000000000000000000000000000000001",
                    },
                },
            ],
        },
        warningMessages: [
            "Duplicate account address in Safeharbor Sheet for chain 'ETHEREUM': 0x2000000000000000000000000000000000000002; first scope=0, duplicate scope=2",
            dedent`
                Asset Recovery Address mismatch for chain 'eip155:1'.
                On-chain: 0x1000000000000000000000000000000000000002
                Safeharbor Sheet: 0x1000000000000000000000000000000000000001
            `,
        ],
        exitCodes: { generate: 2, inspect: 0, verify: 2 },
        generateMessage: "Payload generation blocked: 2 validation warning(s).",
        verifyMessage:
            "SafeHarbor verification failed: 0 update(s), 2 validation warning(s).",
    },
    {
        scenario:
            "unknown on-chain IDs and their duplicate accounts remain inspectable",
        chainCSV: "Name,Chain Id,Asset Recovery Address\n",
        contractCSV: "Status,Chain,Address,isFactory\n",
        details: {
            chains: [
                {
                    caip2ChainId: "eip155:8453",
                    assetRecoveryAddress: "recovery",
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
                    assetRecoveryAddress: "recovery",
                },
            },
            sheetState: {},
            changes: [],
            validationWarnings: [
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
                Unknown chain details in on-chain state: caip2ChainId='eip155:8453'.
                To either remove or keep this chain, please add the chain details to the chain details tab in the Safeharbor Sheet.
            `,
            "Duplicate account address in on-chain state for chain 'eip155:8453': A; first scope=0, duplicate scope=2",
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
            if (command !== "generate") {
                expect(encodeSpy).not.toHaveBeenCalled();
            }
            expect(fetch).toHaveBeenCalledTimes(2);
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
            if (command === "generate") {
                expectedWarnings.push([fixture.generateMessage]);
            }
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
        chainCSV: dedent`
            Name,Chain Id,Asset Recovery Address
            ETHEREUM,eip155:1,0x1000000000000000000000000000000000000001
        `,
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
