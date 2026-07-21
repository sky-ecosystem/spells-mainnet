import { describe, expect, test } from "vitest";
import { verifyPayload } from "../src/verifyPayload.js";

describe("verifyPayload", () => {
    test("accepts an empty payload without validation issues", () => {
        expect(() =>
            verifyPayload({ updates: [], validationIssues: [] }),
        ).not.toThrow();
    });

    test("rejects generated updates", () => {
        expect(() =>
            verifyPayload({
                updates: [
                    {
                        function: "addAccounts",
                        args: ["eip155:1", []],
                        calldata: "0x1234",
                    },
                ],
                validationIssues: [],
            }),
        ).toThrow(/addAccounts/);
    });

    test("rejects validation issues even when the payload is empty", () => {
        expect(() =>
            verifyPayload({
                updates: [],
                validationIssues: ["Unknown chain details in CSV: SOLANA"],
            }),
        ).toThrow(/Unknown chain details in CSV: SOLANA/);
    });
});
