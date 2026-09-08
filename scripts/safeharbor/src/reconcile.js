import {
    getChainDetailsFromSheet,
    getNormalizedContractsInScopeFromSheet,
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "./sheet.js";
import { normalizeOnchainState } from "./agreement.js";
import { validateState } from "./validateState.js";
import { planUpdates } from "./planUpdates.js";

export function createReconciler({ getAgreementDetails }) {
    return async function reconcile() {
        const { chainDetails, validationWarnings: chainDetailsWarnings } =
            await getChainDetailsFromSheet(CHAIN_DETAILS_SHEET_URL);
        const sheetState = await getNormalizedContractsInScopeFromSheet(
            CONTRACTS_IN_SCOPE_SHEET_URL,
        );
        const details = await getAgreementDetails();
        const { onChainState, validationWarnings: onChainWarnings } =
            normalizeOnchainState(details, chainDetails);
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
