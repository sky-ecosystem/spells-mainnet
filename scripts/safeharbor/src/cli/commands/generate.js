import { generatePayload } from "../../generation/index.js";

export function generate(report) {
    const warningCount = report.validationWarnings.length;
    if (warningCount > 0) {
        console.warn(
            `Payload generation blocked: ${warningCount} validation warning(s).`,
        );
        return 2;
    }

    const { updates, solidityCode } = generatePayload(report.changes);
    if (updates.length > 0) {
        console.log(solidityCode);
    }
    console.warn(
        updates.length > 0
            ? "Payload generation completed successfully."
            : "No updates to generate",
    );
    return 0;
}
