export function validateHeaders(headers, requiredHeaders) {
    const missingHeaders = requiredHeaders.filter(
        (header) => !headers.includes(header),
    );
    return missingHeaders.length > 0
        ? [{ code: "MISSING_CSV_HEADERS", context: { missingHeaders } }]
        : [];
}
