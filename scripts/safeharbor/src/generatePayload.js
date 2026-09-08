import {
    getChainDetailsFromSheet,
    getNormalizedContractsInScopeFromSheet,
    CHAIN_DETAILS_SHEET_URL,
    CONTRACTS_IN_SCOPE_SHEET_URL,
} from "./sheet.js";
import { normalizeOnchainState } from "./agreement.js";
import { validateState } from "./validateState.js";
import { generateUpdates } from "./generateUpdates.js";
import { generateSolidityCode } from "./generateSolidity.js";

/**
 * Create a generator that reconciles Safeharbor Sheet and Agreement state without reporting.
 * Validation diagnostics block encoding; fetch, parse, and RPC errors propagate.
 * @param {{getAgreementDetails: () => Promise<object>}} dependencies
 * @returns {() => Promise<{updates: Array<{function: string, args: Array<any>, calldata: string}>, solidityCode: string, validationWarnings: Array<{code: string, context?: object}>}>}
 */
export function createPayloadGenerator({ getAgreementDetails }) {
    return async function generatePayload() {
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
        if (validationWarnings.length > 0) {
            return { updates: [], solidityCode: "", validationWarnings };
        }

        const updates = generateUpdates(onChainState, sheetState, chainDetails);
        return {
            updates,
            solidityCode: generateSolidityCode(updates),
            validationWarnings,
        };
    };
}
