import { checkStateConsistency } from "./checkStateConsistency.js";
import { planUpdates } from "./planUpdates.js";

export async function reconcile({
    getAgreementState,
    getSheetState,
    getSheetChainDetails,
}) {
    const chainDetailsResult = await getSheetChainDetails();
    const [sheetResult, onChainResult] = await Promise.all([
        getSheetState(chainDetailsResult.value),
        getAgreementState(chainDetailsResult.value),
    ]);
    const validationWarnings = [
        ...chainDetailsResult.warnings,
        ...onChainResult.warnings,
        ...sheetResult.warnings,
        ...checkStateConsistency(
            onChainResult.value,
            sheetResult.value,
            chainDetailsResult.value,
        ),
    ];

    return {
        chainDetails: chainDetailsResult.value,
        onChainState: onChainResult.value,
        sheetState: sheetResult.value,
        changes:
            validationWarnings.length > 0
                ? []
                : planUpdates(
                      onChainResult.value,
                      sheetResult.value,
                      chainDetailsResult.value,
                  ),
        validationWarnings,
    };
}
