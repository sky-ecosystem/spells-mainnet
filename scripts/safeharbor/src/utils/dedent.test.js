import { expect, test } from "vitest";
import { dedent } from "./dedent.js";

test("removes surrounding blank lines and common indentation", () => {
    expect(dedent`

        if (ready) {
            run();

            finish();
        }

    `).toBe("if (ready) {\n    run();\n\n    finish();\n}");
});

test("preserves trailing whitespace, cooked escapes, and interpolated values", () => {
    expect(dedent`
        first\tvalue${"  "}
        second ${0}
    `).toBe("first\tvalue  \nsecond 0");
});

test("preserves relative indentation when the first line is unindented", () => {
    expect(dedent`first
    second`).toBe("first\n    second");
});

test("returns an empty string for empty or whitespace-only templates", () => {
    expect(dedent``).toBe("");
    expect(dedent`

    `).toBe("");
});
