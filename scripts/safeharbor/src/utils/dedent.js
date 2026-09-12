export function dedent(strings, ...values) {
    // A template tag receives text segments and interpolated values separately.
    // Supplying the cooked segments as "raw" lets String.raw join them while
    // preserving normal escape handling (for example, \t becomes a tab).
    const lines = String.raw({ raw: strings }, ...values)
        // Remove surrounding blank lines, not whitespace on content lines.
        .replace(/^(?:[ \t]*\n)+|(?:\n[ \t]*)+$/g, "")
        .split("\n");
    // The least-indented content line determines how much to remove from all
    // content lines. Blank lines must not lower that shared indentation to zero.
    const indentation = Math.min(
        ...lines.filter((line) => line.trim().length > 0).map((line) => line.match(/^[ \t]*/)[0].length),
    );

    // Keep relative indentation and trailing whitespace; normalize blank lines
    // to empty strings so indentation-only spaces do not enter the fixture.
    return lines.map((line) => (line.trim().length > 0 ? line.slice(indentation) : "")).join("\n");
}
