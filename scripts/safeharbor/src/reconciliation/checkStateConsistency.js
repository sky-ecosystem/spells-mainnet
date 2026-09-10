import { getAddress } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";

export function checkStateConsistency(agreementOnChainState, sheetState) {
    return Object.keys(sheetState).flatMap((chainId) =>
        checkChainRecoveryAddress(chainId, agreementOnChainState, sheetState),
    );
}

function checkChainRecoveryAddress(chainId, agreementOnChainState, sheetState) {
    const recoveryDetails = {
        chainId,
        isNewChain: !agreementOnChainState[chainId],
        onChainRecoveryAddress:
            agreementOnChainState[chainId]?.assetRecoveryAddress,
        sheetRecoveryAddress: sheetState[chainId].assetRecoveryAddress,
    };
    return validateRecoveryAddress(recoveryDetails).map((diagnostic) =>
        addRecoveryAddressContext(diagnostic, recoveryDetails),
    );
}

function validateRecoveryAddress({
    chainId,
    isNewChain,
    onChainRecoveryAddress,
    sheetRecoveryAddress,
}) {
    const missingOnChainRecoveryAddress =
        !isNewChain && !onChainRecoveryAddress;
    if (!sheetRecoveryAddress && !missingOnChainRecoveryAddress) {
        return [];
    }
    if (missingOnChainRecoveryAddress) {
        return [{ code: $.MISSING_ONCHAIN_RECOVERY_ADDRESS }];
    }
    if (isNewChain) {
        return checkNewRecoveryAddress(chainId, sheetRecoveryAddress);
    }
    return getRecoveryAddressComparator(chainId)(
        onChainRecoveryAddress,
        sheetRecoveryAddress,
    );
}

function addRecoveryAddressContext(
    { code },
    { chainId, isNewChain, onChainRecoveryAddress, sheetRecoveryAddress },
) {
    if (code === $.MISSING_ONCHAIN_RECOVERY_ADDRESS) {
        return { code, context: { chainId } };
    }
    return {
        code,
        context: {
            chainId,
            ...(code === $.INVALID_EVM_RECOVERY_ADDRESS ? { isNewChain } : {}),
            onChainRecoveryAddress,
            sheetRecoveryAddress,
        },
    };
}

function checkNewRecoveryAddress(chainId, address) {
    if (chainId.startsWith("eip155:")) {
        return checkEvmRecoveryAddress(address);
    }

    return [];
}

function getRecoveryAddressComparator(chainId) {
    if (chainId.startsWith("eip155:")) {
        return compareEvmRecoveryAddresses;
    }

    return compareNonEvmRecoveryAddresses;
}

function checkEvmRecoveryAddress(address) {
    try {
        getAddress(address);
        return [];
    } catch {
        return [{ code: $.INVALID_EVM_RECOVERY_ADDRESS }];
    }
}

function compareEvmRecoveryAddresses(onChainAddress, sheetAddress) {
    try {
        if (getAddress(onChainAddress) === getAddress(sheetAddress)) {
            return [];
        }

        return [{ code: $.RECOVERY_ADDRESS_MISMATCH }];
    } catch {
        return [{ code: $.INVALID_EVM_RECOVERY_ADDRESS }];
    }
}

function compareNonEvmRecoveryAddresses(onChainAddress, sheetAddress) {
    if (onChainAddress === sheetAddress) {
        return [];
    }

    return [{ code: $.RECOVERY_ADDRESS_MISMATCH }];
}
