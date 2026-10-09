import { planUpdates } from "./planUpdates.js";
import { validateStates } from "./validateStates.js";

export async function reconcile({ getAgreementState, getSheetState, getSheetChainDetails }) {
    const sheetChainDetailsResult = await loadWithSourceContext("sheetChainDetails", getSheetChainDetails, []);
    const sheetResult = await loadWithSourceContext("sheetState", getSheetState, [sheetChainDetailsResult.value]);
    const agreementOnChainResult = await loadWithSourceContext("agreementOnChainState", getAgreementState, [
        Object.keys(sheetResult.value),
    ]);
    const warnings = validateStates({ sheetChainDetailsResult, agreementOnChainResult, sheetResult });

    return {
        sheetChainDetails: sheetChainDetailsResult.value,
        agreementOnChainState: agreementOnChainResult.value,
        sheetState: sheetResult.value,
        changes: warnings.length > 0 ? [] : planUpdates(agreementOnChainResult.value, sheetResult.value),
        warnings,
    };
}

async function loadWithSourceContext(source, load, args) {
    try {
        return await load(...args);
    } catch (error) {
        throw Object.assign(new Error(String(error?.message ?? error), { cause: error }), {
            source,
            diagnostic: error?.diagnostic,
        });
    }
}
