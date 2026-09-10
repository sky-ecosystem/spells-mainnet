import { downloadAndParse } from "./csv.js";
import {
    normalizeChainDetails,
    normalizeContractsInScope,
} from "./normalize.js";

export async function getSheetState(sheetChainDetails) {
    return normalizeContractsInScope(
        await downloadAndParse(CONTRACTS_IN_SCOPE_SHEET_URL),
        sheetChainDetails,
    );
}

export async function getSheetChainDetails() {
    return normalizeChainDetails(
        await downloadAndParse(CHAIN_DETAILS_SHEET_URL),
    );
}

const WORKBOOK_URL =
    "https://docs.google.com/spreadsheets/d/1e_KOYOeBGaA5EG3Xqco6lOP_a0zV4Vrm3w5-dqFk00U";

const CONTRACTS_IN_SCOPE_SHEET_URL = `${WORKBOOK_URL}/export?format=csv&gid=1121763694`;
const CHAIN_DETAILS_SHEET_URL = `${WORKBOOK_URL}/export?format=csv&gid=1620276618`;
