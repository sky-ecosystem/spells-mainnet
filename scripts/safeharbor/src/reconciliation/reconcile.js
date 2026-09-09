import {
    getChainDetailsFromSheet,
    getNormalizedContractsInScopeFromSheet,
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "../sheet/index.js";
import { validateState } from "./validateState.js";
import { planUpdates } from "./planUpdates.js";

export function createReconciler({ getAgreementState }) {
    return async function reconcile() {
        const { chainDetails, validationWarnings: chainDetailsWarnings } =
            await getChainDetailsFromSheet(CHAIN_DETAILS_SHEET_URL);
        const sheetState = await getNormalizedContractsInScopeFromSheet(
            CONTRACTS_IN_SCOPE_SHEET_URL,
        );
        const { onChainState, validationWarnings: onChainWarnings } =
            await getAgreementState(chainDetails);
        const validationWarnings = [
            ...chainDetailsWarnings,
            ...onChainWarnings,
            ...validateState(onChainState, sheetState, chainDetails),
        ];

        return {
            chainDetails,
            onChainState,
            sheetState,
            changes:
                validationWarnings.length > 0
                    ? null
                    : planUpdates(onChainState, sheetState, chainDetails),
            validationWarnings,
        };
    };
}
