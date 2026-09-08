export function findDuplicateIndexes(values) {
    const firstIndexes = values.reduce(
        (indexes, value, index) =>
            indexes.has(value) ? indexes : indexes.set(value, index),
        new Map(),
    );

    return new Set(
        values.flatMap((value, index) =>
            firstIndexes.get(value) === index ? [] : [index],
        ),
    );
}
