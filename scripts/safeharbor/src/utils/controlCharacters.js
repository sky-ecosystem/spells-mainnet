// Unicode Control (C0/C1/DEL), Bidi_Control, and line/paragraph separators.
// https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Unicode_character_class_escape
const unsafeCharacters = /[\p{General_Category=Control}\p{Bidi_Control}\u2028\u2029]/gu;

/** Detects unsafe Sheet characters; terminal output may preserve line feeds. */
export function hasUnsafeControlCharacter(value, { allowLineFeed = false } = {}) {
    for (const match of String(value).matchAll(unsafeCharacters)) {
        if (!allowLineFeed || match[0] !== "\n") {
            return true;
        }
    }
    return false;
}

/** Renders unsafe terminal characters visibly while preserving multiline layout. */
export function escapeTerminalControlCharacters(value) {
    return String(value).replace(unsafeCharacters, (character) => {
        switch (character) {
            case "\n":
                return "\n";
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
    });
}
