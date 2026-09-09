import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { getAddress } from "ethers";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function checkStateConsistency(onChainState, sheetState, chainDetails) {
    return [
        ...validateRecoveryAddresses(onChainState, sheetState, chainDetails),
        ...validateUniqueAccounts(onChainState),
    ];
}

function validateUniqueAccounts(onChainState) {
    const validateOnChainAccounts = (chainName) =>
        findDuplicateAccountAddresses(onChainState[chainName].accounts).map(
            (address) => ({
                code: $.DUPLICATE_ONCHAIN_ACCOUNT,
                context: { chainName, address },
            }),
        );

    return Object.keys(onChainState).flatMap(validateOnChainAccounts);
}

function validateRecoveryAddresses(onChainState, sheetState, chainDetails) {
    const validateRecoveryAddress = (chainName) => {
        const isNewChain = !Object.hasOwn(onChainState, chainName);
        const onChainRecoveryAddress =
            onChainState[chainName]?.assetRecoveryAddress;
        const sheetRecoveryAddress =
            chainDetails.assetRecoveryAddress[chainName];
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

        return getRecoveryAddressValidator(
            chainDetails.caip2ChainId[chainName],
        )({
            chainName,
            isNewChain,
            onChainRecoveryAddress,
            sheetRecoveryAddress,
        });
    };

    return Object.keys(sheetState).flatMap(validateRecoveryAddress);
}

function getRecoveryAddressValidator(chainId) {
    if (chainId?.startsWith("eip155:")) {
        return validateEvmRecoveryAddress;
    }

    return validateNonEvmRecoveryAddress;
}

function validateEvmRecoveryAddress({
    chainName,
    isNewChain,
    onChainRecoveryAddress,
    sheetRecoveryAddress,
}) {
    try {
        if (isNewChain) {
            getAddress(sheetRecoveryAddress);
            return [];
        }

        if (
            getAddress(onChainRecoveryAddress) ===
            getAddress(sheetRecoveryAddress)
        ) {
            return [];
        }

        return [
            {
                code: $.RECOVERY_ADDRESS_MISMATCH,
                context: {
                    chainName,
                    onChainRecoveryAddress,
                    sheetRecoveryAddress,
                },
            },
        ];
    } catch {
        return [
            {
                code: $.INVALID_EVM_RECOVERY_ADDRESS,
                context: {
                    chainName,
                    isNewChain,
                    onChainRecoveryAddress,
                    sheetRecoveryAddress,
                },
            },
        ];
    }
}

function validateNonEvmRecoveryAddress({
    chainName,
    isNewChain,
    onChainRecoveryAddress,
    sheetRecoveryAddress,
}) {
    if (isNewChain || onChainRecoveryAddress === sheetRecoveryAddress) {
        return [];
    }

    return [
        {
            code: $.RECOVERY_ADDRESS_MISMATCH,
            context: {
                chainName,
                onChainRecoveryAddress,
                sheetRecoveryAddress,
            },
        },
    ];
}

function findDuplicateAccountAddresses(accounts) {
    const addresses = accounts.map(({ accountAddress }) => accountAddress);
    return [
        ...new Set(
            [...findDuplicateIndexes(addresses)].map(
                (index) => addresses[index],
            ),
        ),
    ];
}
