/**
 * Returns true when text contains characters that can affect terminal rendering or
 * make Sheet content visually ambiguous. This includes ASCII/C1 controls and
 * Unicode bidirectional-formatting controls. Line feed can be allowed for
 * terminal output so existing multiline diagnostics keep their layout.
 *
 * The implementation intentionally avoids regular expressions: ESLint's
 * no-control-regex rule treats control-character ranges as likely mistakes.
 */
export function hasUnsafeControlCharacter(value, { allowLineFeed = false } = {}) {
    return Array.from(String(value)).some((character) => isUnsafeControlCharacter(character, { allowLineFeed }));
}

/**
 * Escapes terminal-control characters into visible JavaScript-style sequences so
 * untrusted text can be printed without being interpreted by the terminal.
 */
export function escapeTerminalControlCharacters(value) {
    return Array.from(String(value), (character) => {
        if (!isUnsafeControlCharacter(character, { allowLineFeed: true })) {
            return character;
        }
        switch (character) {
            case "\t":
                return "\\t";
            case "\b":
                return "\\b";
            case "\v":
                return "\\v";
            case "\f":
                return "\\f";
            case "\r":
                return "\\r";
            default: {
                const codePoint = character.codePointAt(0);
                return codePoint <= 0xff
                    ? `\\x${codePoint.toString(16).padStart(2, "0")}`
                    : `\\u${codePoint.toString(16).padStart(4, "0")}`;
            }
        }
    }).join("");
}

function isUnsafeControlCharacter(character, { allowLineFeed }) {
    const codePoint = character.codePointAt(0);
    if (allowLineFeed && codePoint === 0x0a) {
        return false;
    }
    return (
        // Unicode C0/C1 controls include terminal escapes, erases, CR, NUL and DEL.
        // https://www.unicode.org/charts/PDF/U0000.pdf
        // https://www.unicode.org/charts/PDF/U0080.pdf
        // Terminal semantics are standardized by ECMA-48 / ISO/IEC 6429.
        // https://ecma-international.org/publications-and-standards/standards/ecma-48/
        (codePoint >= 0x00 && codePoint <= 0x1f) ||
        (codePoint >= 0x7f && codePoint <= 0x9f) ||
        // Bidirectional formatting controls can make Sheet/review text visually misleading.
        // https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt
        codePoint === 0x61c ||
        (codePoint >= 0x200e && codePoint <= 0x200f) ||
        (codePoint >= 0x202a && codePoint <= 0x202e) ||
        (codePoint >= 0x2066 && codePoint <= 0x2069) ||
        // JSON.stringify preserves these raw, but JavaScript treats them as line separators.
        codePoint === 0x2028 ||
        codePoint === 0x2029
    );
}
