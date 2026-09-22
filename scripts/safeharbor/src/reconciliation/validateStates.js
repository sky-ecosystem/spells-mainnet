import { getAddress } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";

export function validateStates({ sheetChainDetailsResult, agreementOnChainResult, sheetResult }) {
    const warnings = [
        ...sheetChainDetailsResult.warnings,
        ...validateKnownOnChainIds(agreementOnChainResult.value, sheetChainDetailsResult.value),
        ...agreementOnChainResult.warnings,
        ...sheetResult.warnings,
    ];
    return [...warnings, ...compareRecoveryAddresses(agreementOnChainResult.value, sheetResult.value, warnings)];
}

function validateKnownOnChainIds(agreementOnChainState, sheetChainDetails) {
    return Object.keys(agreementOnChainState)
        .filter((chainId) => !sheetChainDetails.name[chainId])
        .map((chainId) => ({
            code: $.UNKNOWN_ONCHAIN_CHAIN,
            context: { chainId },
        }));
}

function compareRecoveryAddresses(agreementOnChainState, sheetState, warnings) {
    const nonComparableRecoveryChainIds = getNonComparableRecoveryChainIds(sheetState, warnings);
    return Object.keys(sheetState).flatMap((chainId) =>
        compareChainRecoveryAddresses(chainId, agreementOnChainState, sheetState, nonComparableRecoveryChainIds),
    );
}

function getNonComparableRecoveryChainIds(sheetState, warnings) {
    return new Set(
        warnings
            .filter(
                ({ code, context }) =>
                    (code === $.INVALID_SHEET_RECOVERY_ADDRESS &&
                        sheetState[context.chainId]?.assetRecoveryAddress === context.address) ||
                    code === $.INVALID_ONCHAIN_RECOVERY_ADDRESS,
            )
            .map(({ context }) => context.chainId),
    );
}

function compareChainRecoveryAddresses(chainId, agreementOnChainState, sheetState, nonComparableRecoveryChainIds) {
    const recoveryDetails = {
        chainId,
        isNewChain: !agreementOnChainState[chainId],
        isRecoveryInvalid: nonComparableRecoveryChainIds.has(chainId),
        onChainRecoveryAddress: agreementOnChainState[chainId]?.assetRecoveryAddress,
        sheetRecoveryAddress: sheetState[chainId].assetRecoveryAddress,
    };
    return compareRecoveryAddress(recoveryDetails).map(({ code }) => ({
        code,
        context: {
            chainId,
            onChainRecoveryAddress: recoveryDetails.onChainRecoveryAddress,
            sheetRecoveryAddress: recoveryDetails.sheetRecoveryAddress,
        },
    }));
}

function compareRecoveryAddress({
    chainId,
    isNewChain,
    isRecoveryInvalid,
    onChainRecoveryAddress,
    sheetRecoveryAddress,
}) {
    if (isNewChain || isRecoveryInvalid) {
        return [];
    }
    return getRecoveryAddressComparator(chainId)(onChainRecoveryAddress, sheetRecoveryAddress);
}

function getRecoveryAddressComparator(chainId) {
    if (chainId.startsWith("eip155:")) {
        return compareEvmRecoveryAddresses;
    }

    return compareNonEvmRecoveryAddresses;
}

function compareEvmRecoveryAddresses(onChainAddress, sheetAddress) {
    if (getAddress(onChainAddress) === getAddress(sheetAddress)) {
        return [];
    }
    return [{ code: $.RECOVERY_ADDRESS_MISMATCH }];
}

function compareNonEvmRecoveryAddresses(onChainAddress, sheetAddress) {
    if (onChainAddress === sheetAddress) {
        return [];
    }

    return [{ code: $.RECOVERY_ADDRESS_MISMATCH }];
}
