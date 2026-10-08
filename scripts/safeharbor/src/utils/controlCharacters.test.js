import { expect, test } from "vitest";
import { escapeTerminalControlCharacters, hasUnsafeControlCharacter } from "./controlCharacters.js";

test("detects control characters relevant to Sheet input", () => {
    expect(hasUnsafeControlCharacter("safe text")).toBe(false);
    expect(hasUnsafeControlCharacter("line\nbreak")).toBe(true);
    expect(hasUnsafeControlCharacter("ansi\u001b[2K")).toBe(true);
    expect(hasUnsafeControlCharacter("c1-csi\u009b2K")).toBe(true);
    expect(hasUnsafeControlCharacter("bidi\u202econtrol")).toBe(true);
    expect(hasUnsafeControlCharacter("emoji grapheme 👨‍👩‍👧‍👦")).toBe(false);
    expect(hasUnsafeControlCharacter("emoji grapheme with escape 👨‍\u001b[2K👩")).toBe(true);
});

test("escapes terminal controls while preserving line feeds", () => {
    expect(escapeTerminalControlCharacters("bad\u001b[2K\rhidden\nnext\u202e")).toBe(
        "bad\\x1b[2K\\rhidden\nnext\\u202e",
    );
});
