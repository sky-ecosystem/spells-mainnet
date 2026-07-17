export function verifyPayload({ updates, validationIssues }) {
    const failures = [
        ...validationIssues,
        ...updates.map((update) =>
            JSON.stringify({
                function: update.function,
                args: update.args,
                calldata: update.calldata,
            }),
        ),
    ];

    if (failures.length > 0) {
        throw new Error(
            `SafeHarbor verification failed:\n${failures.join("\n")}`,
        );
    }
}
