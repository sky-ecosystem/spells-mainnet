import { expect, test } from "vitest";
import { findDuplicateIndexes } from "./findDuplicateIndexes.js";

test.each([
    {
        scenario: "empty input",
        values: [],
        expected: [],
    },
    {
        scenario: "unique values",
        values: ["A", "B", "C"],
        expected: [],
    },
    {
        scenario: "every occurrence after the first",
        values: ["A", "A", "A"],
        expected: [1, 2],
    },
    {
        scenario: "interleaved duplicates in index order",
        values: ["A", "B", "B", "C", "A", "B", "C"],
        expected: [2, 4, 5, 6],
    },
    {
        scenario: "case-sensitive strings",
        values: ["Account", "account", "Account", "ACCOUNT", "account"],
        expected: [2, 4],
    },
])("finds duplicate indexes for $scenario", ({ values, expected }) => {
    const result = findDuplicateIndexes(Object.freeze(values));

    expect(result).toBeInstanceOf(Set);
    expect([...result]).toEqual(expected);
});
