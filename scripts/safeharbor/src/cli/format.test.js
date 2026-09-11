import { expect, test } from "vitest";
import { dedent } from "../utils/dedent.js";
import { formatOperationalError } from "./format.js";

test.each([
    { scenario: "missing", code: undefined },
    { scenario: "numeric", code: 503 },
    { scenario: "object", code: { secret: "private code metadata" } },
    { scenario: "empty", code: "" },
    { scenario: "lowercase", code: "econnreset" },
    { scenario: "numeric prefix", code: "1ERROR" },
    { scenario: "multiline", code: "NETWORK_ERROR\nprivate token" },
])("omits $scenario codes without increasing cause indentation", ({ code }) => {
    const failure = Object.assign(
        new Error("CSV unavailable", {
            cause: Object.assign(
                new Error("private network details", {
                    cause: new Error("codeless private details", {
                        cause: Object.assign(
                            new Error("private invalid-code details", {
                                cause: Object.assign(
                                    new Error("private socket details"),
                                    { code: "ECONNRESET" },
                                ),
                            }),
                            { code },
                        ),
                    }),
                }),
                { code: "NETWORK_ERROR" },
            ),
        }),
        { code },
    );
    expect(formatOperationalError(failure)).toBe(dedent`
        Failed to execute command:
        CSV unavailable
            Cause: NETWORK_ERROR
                Cause: ECONNRESET
    `);
});

test("retains repeated codes on distinct causes and stops at a repeated object", () => {
    const firstCause = Object.assign(new Error("first private failure"), {
        code: "NETWORK_ERROR",
    });
    const secondCause = Object.assign(
        new Error("second private failure", { cause: firstCause }),
        { code: "NETWORK_ERROR" },
    );
    firstCause.cause = secondCause;
    expect(
        formatOperationalError(
            new Error("CSV unavailable", { cause: firstCause }),
        ),
    ).toBe(dedent`
        Failed to execute command:
        CSV unavailable
            Cause: NETWORK_ERROR
                Cause: NETWORK_ERROR
    `);
});
