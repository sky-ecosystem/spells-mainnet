import { checkStateConsistency } from "./checkStateConsistency.js";
import { planUpdates } from "./planUpdates.js";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";

export async function reconcile({
    getAgreementState,
    getSheetState,
    getSheetChainDetails,
}) {
    const sheetChainDetailsResult = await getSheetChainDetails();
    const [sheetResult, agreementOnChainResult] = await Promise.all([
        getSheetState(sheetChainDetailsResult.value),
        getAgreementState(),
    ]);
    const validationWarnings = [
        ...sheetChainDetailsResult.warnings,
        ...validateKnownOnChainIds(
            agreementOnChainResult.value,
            sheetChainDetailsResult.value,
        ),
        ...agreementOnChainResult.warnings,
        ...sheetResult.warnings,
        ...checkStateConsistency(
            agreementOnChainResult.value,
            sheetResult.value,
            sheetChainDetailsResult.value,
        ),
    ];

    return {
        sheetChainDetails: sheetChainDetailsResult.value,
        agreementOnChainState: agreementOnChainResult.value,
        sheetState: sheetResult.value,
        changes:
            validationWarnings.length > 0
                ? []
                : planUpdates(
                      agreementOnChainResult.value,
                      sheetResult.value,
                      sheetChainDetailsResult.value,
                  ),
        validationWarnings,
    };
}

function validateKnownOnChainIds(agreementOnChainState, sheetChainDetails) {
    return Object.keys(agreementOnChainState)
        .filter((chainId) => !Object.hasOwn(sheetChainDetails.name, chainId))
        .map((chainId) => ({
            code: $.UNKNOWN_ONCHAIN_CHAIN,
            context: { chainId },
        }));
}
