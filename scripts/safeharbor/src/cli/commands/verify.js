export function verify(report) {
    const updateCount = report.changes.length;
    const warningCount = report.validationWarnings.length;
    if (updateCount === 0 && warningCount === 0) {
        console.log("✅ SafeHarbor verification passed: no updates or validation warnings.");
        return 0;
    }

    console.log(`❌ SafeHarbor verification failed: ${updateCount} update(s), ${warningCount} validation warning(s).`);
    return 2;
}
