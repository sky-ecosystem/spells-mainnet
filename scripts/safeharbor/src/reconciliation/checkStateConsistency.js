import { getAddress } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";

export function checkStateConsistency(onChainState, sheetState, chainDetails) {
    const validateRecoveryAddress = (chainName) => {
        const isNewChain = !Object.hasOwn(onChainState, chainName);
        const onChainRecoveryAddress =
            onChainState[chainName]?.assetRecoveryAddress;
        const sheetRecoveryAddress = Object.hasOwn(
            chainDetails.assetRecoveryAddress,
            chainName,
        )
            ? chainDetails.assetRecoveryAddress[chainName]
            : undefined;
        const missingOnChainRecoveryAddress =
            !isNewChain && !onChainRecoveryAddress;

        if (!sheetRecoveryAddress && !missingOnChainRecoveryAddress) {
            return [];
        }

        if (missingOnChainRecoveryAddress) {
            return [
                {
                    code: $.MISSING_ONCHAIN_RECOVERY_ADDRESS,
                    context: { chainName },
                },
            ];
        }

        const chainId = chainDetails.caip2ChainId[chainName];
        const addContext = ({ code }) => ({
            code,
            context: {
                chainName,
                ...(code === $.INVALID_EVM_RECOVERY_ADDRESS
                    ? { isNewChain }
                    : {}),
                onChainRecoveryAddress,
                sheetRecoveryAddress,
            },
        });

        if (isNewChain) {
            return checkNewRecoveryAddress(chainId, sheetRecoveryAddress).map(
                addContext,
            );
        }

        return getRecoveryAddressComparator(chainId)(
            onChainRecoveryAddress,
            sheetRecoveryAddress,
        ).map(addContext);
    };

    return Object.keys(sheetState).flatMap(validateRecoveryAddress);
}

function checkNewRecoveryAddress(chainId, address) {
    if (chainId?.startsWith("eip155:")) {
        return checkEvmRecoveryAddress(address);
    }

    return [];
}

function getRecoveryAddressComparator(chainId) {
    if (chainId?.startsWith("eip155:")) {
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
