export function formatList(values) {
    return listFormatter.format(values);
}

// `unit` separates values with commas without adding a final conjunction.
const listFormatter = new Intl.ListFormat("en", {
    style: "long",
    type: "unit",
});
