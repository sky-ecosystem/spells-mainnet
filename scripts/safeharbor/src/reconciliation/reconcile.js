import { checkStateConsistency } from "./checkStateConsistency.js";
import { planUpdates } from "./planUpdates.js";

export async function reconcile({
    getAgreementState,
    getSheetState,
    getSheetChainDetails,
}) {
    const { chainDetails, validationWarnings: chainDetailsWarnings } =
        await getSheetChainDetails();
    const [
        { state: sheetState, warnings: sheetWarnings },
        { state: onChainState, warnings: onChainWarnings },
    ] = await Promise.all([
        getSheetState(chainDetails),
        getAgreementState(chainDetails),
    ]);
    const validationWarnings = [
        ...chainDetailsWarnings,
        ...onChainWarnings,
        ...sheetWarnings,
        ...checkStateConsistency(onChainState, sheetState, chainDetails),
    ];

    return {
        chainDetails,
        onChainState,
        sheetState,
        changes:
            validationWarnings.length > 0
                ? []
                : planUpdates(onChainState, sheetState, chainDetails),
        validationWarnings,
    };
}
