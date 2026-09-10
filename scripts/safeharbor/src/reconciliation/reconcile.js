import { checkStateConsistency } from "./checkStateConsistency.js";
import { planUpdates } from "./planUpdates.js";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";

export async function reconcile({
    getAgreementState,
    getSheetState,
    getSheetChainDetails,
}) {
    const sheetChainDetailsResult = await loadSource(
        "sheetChainDetails",
        getSheetChainDetails,
    );
    const [sheetResult, agreementOnChainResult] = await Promise.all([
        loadSource("sheetState", () =>
            getSheetState(sheetChainDetailsResult.value),
        ),
        loadSource("agreementOnChainState", getAgreementState),
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
        ),
    ];

    return {
        sheetChainDetails: sheetChainDetailsResult.value,
        agreementOnChainState: agreementOnChainResult.value,
        sheetState: sheetResult.value,
        changes:
            validationWarnings.length > 0
                ? []
                : planUpdates(agreementOnChainResult.value, sheetResult.value),
        validationWarnings,
    };
}

async function loadSource(source, load) {
    try {
        return await load();
    } catch (error) {
        throw Object.assign(
            new Error(String(error?.message ?? error), { cause: error }),
            {
                source,
                diagnostic: error?.diagnostic,
            },
        );
    }
}

function validateKnownOnChainIds(agreementOnChainState, sheetChainDetails) {
    return Object.keys(agreementOnChainState)
        .filter((chainId) => !sheetChainDetails.name[chainId])
        .map((chainId) => ({
            code: $.UNKNOWN_ONCHAIN_CHAIN,
            context: { chainId },
        }));
}
