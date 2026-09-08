import { expect, test } from "vitest";
import { validateHeaders } from "./validateHeaders.js";

test("returns every missing header in required order", () => {
    expect(validateHeaders(["Status"], ["Status", "Chain", "Address"])).toEqual(
        [
            {
                code: "MISSING_CSV_HEADERS",
                context: { missingHeaders: ["Chain", "Address"] },
            },
        ],
    );
});

test("accepts required headers with extra columns", () => {
    expect(
        validateHeaders(["Notes", "Chain", "Status"], ["Status", "Chain"]),
    ).toEqual([]);
});
