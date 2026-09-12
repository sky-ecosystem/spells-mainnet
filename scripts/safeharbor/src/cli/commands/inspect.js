export function inspect(report) {
    console.log(JSON.stringify(report, (_key, value) => (typeof value === "bigint" ? value.toString() : value), 2));
    return 0;
}
