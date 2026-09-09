import {
    getChainDetailsFromSheet,
    getNormalizedContractsInScopeFromSheet,
} from "../sheet/index.js";
import { checkStateConsistency } from "./checkStateConsistency.js";
import { planUpdates } from "./planUpdates.js";

export function createReconciler({ getAgreementState }) {
    return async function reconcile() {
        const { chainDetails, validationWarnings: chainDetailsWarnings } =
            await getChainDetailsFromSheet();
        const sheetState = await getNormalizedContractsInScopeFromSheet();
        const { onChainState, validationWarnings: onChainWarnings } =
            await getAgreementState(chainDetails);
        const validationWarnings = [
            ...chainDetailsWarnings,
            ...onChainWarnings,
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
    };
}
