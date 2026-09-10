import { getAddress } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

export function checkStateConsistency(
    agreementOnChainState,
    sheetState,
    sheetChainDetails,
) {
    return Object.keys(sheetState).flatMap((chainId) =>
        checkChainRecoveryAddress(
            chainId,
            agreementOnChainState,
            sheetChainDetails,
        ),
    );
}

function checkChainRecoveryAddress(
    chainId,
    agreementOnChainState,
    sheetChainDetails,
) {
    const recoveryDetails = getRecoveryAddressDetails(
        chainId,
        agreementOnChainState,
        sheetChainDetails,
    );
    return validateRecoveryAddress(recoveryDetails).map((diagnostic) =>
        addRecoveryAddressContext(diagnostic, recoveryDetails),
    );
}

function getRecoveryAddressDetails(
    chainId,
    agreementOnChainState,
    sheetChainDetails,
) {
    const chainName = Object.hasOwn(sheetChainDetails.name, chainId)
        ? sheetChainDetails.name[chainId]
        : chainId;
    return {
        chainId,
        chainName,
        isNewChain: !Object.hasOwn(agreementOnChainState, chainId),
        onChainRecoveryAddress:
            agreementOnChainState[chainId]?.assetRecoveryAddress,
        sheetRecoveryAddress: Object.hasOwn(
            sheetChainDetails.assetRecoveryAddress,
            chainName,
        )
            ? sheetChainDetails.assetRecoveryAddress[chainName]
            : undefined,
    };
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
    { chainName, isNewChain, onChainRecoveryAddress, sheetRecoveryAddress },
) {
    if (code === $.MISSING_ONCHAIN_RECOVERY_ADDRESS) {
        return { code, context: { chainName } };
    }
    return {
        code,
        context: {
            chainName,
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
