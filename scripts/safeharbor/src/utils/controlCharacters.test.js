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

    // Check exact ranges from the spec
    for (const [first, last] of [
        // Unicode C0 Controls: https://www.unicode.org/charts/PDF/U0000.pdf
        [0x00, 0x1f],
        // Unicode DEL + C1 Controls: https://www.unicode.org/charts/PDF/U0080.pdf
        [0x7f, 0x9f],
        // Unicode bidirectional format controls: https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt
        [0x61c, 0x61c],
        [0x200e, 0x200f],
        [0x202a, 0x202e],
        [0x2066, 0x2069],
        // Unicode line separators: https://www.unicode.org/charts/PDF/U2000.pdf
        [0x2028, 0x2029],
    ]) {
        for (let codePoint = first; codePoint <= last; codePoint++) {
            expect(hasUnsafeControlCharacter(`x${String.fromCodePoint(codePoint)}y`)).toBe(true);
        }
    }

    // Check edge cases
    for (const codePoint of [0x20, 0x7e, 0xa0, 0x202f, 0x2065, 0x206a]) {
        expect(hasUnsafeControlCharacter(`x${String.fromCodePoint(codePoint)}y`)).toBe(false);
    }
});

test("escapes terminal controls while preserving line feeds", () => {
    expect(escapeTerminalControlCharacters("bad\u001b[2K\rhidden\nnext\u202e")).toBe(
        "bad\\x1b[2K\\rhidden\nnext\\u202e",
    );
});
