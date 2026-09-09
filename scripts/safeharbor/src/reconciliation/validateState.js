import { DIAGNOSTIC_CODES as $ } from "../diagnosticCodes.js";
import { getAddress } from "ethers";
import { findDuplicateIndexes } from "../findDuplicateIndexes.js";

export function validateState(onChainState, sheetState, chainDetails) {
    const {
        validateRecoveryAddresses,
        validateKnownChains,
        validateUniqueAccounts,
    } = createStateValidators(onChainState, sheetState, chainDetails);

    return [
        ...validateRecoveryAddresses(),
        ...validateKnownChains(),
        ...validateUniqueAccounts(),
    ];
}

export function createStateValidators(onChainState, sheetState, chainDetails) {
    function validateUniqueAccounts() {
        return [
            ...Object.keys(sheetState).flatMap(validateSheetAccounts),
            ...Object.keys(onChainState).flatMap(validateOnChainAccounts),
        ];
    }

    function validateSheetAccounts(chainName) {
        return findDuplicateAccountAddresses(sheetState[chainName]).map(
            (address) => ({
                code: $.DUPLICATE_SHEET_ACCOUNT,
                context: { chainName, address },
            }),
        );
    }

    function validateOnChainAccounts(chainName) {
        return findDuplicateAccountAddresses(
            onChainState[chainName].accounts,
        ).map((address) => ({
            code: $.DUPLICATE_ONCHAIN_ACCOUNT,
            context: { chainName, address },
        }));
    }

    function validateRecoveryAddresses() {
        return Object.keys(sheetState).flatMap(validateRecoveryAddress);
    }

    function validateKnownChains() {
        return Object.keys(sheetState)
            .filter(
                (chainName) =>
                    !Object.hasOwn(chainDetails.caip2ChainId, chainName),
            )
            .map((chainName) => ({
                code: $.UNKNOWN_SHEET_CHAIN,
                context: { chainName },
            }));
    }

    function validateRecoveryAddress(chainName) {
        const isNewChain = !Object.hasOwn(onChainState, chainName);
        const onChainRecoveryAddress =
            onChainState[chainName]?.assetRecoveryAddress;
        const sheetRecoveryAddress =
            chainDetails.assetRecoveryAddress[chainName];

        if (!isNewChain && !onChainRecoveryAddress) {
            return [
                {
                    code: $.MISSING_ONCHAIN_RECOVERY_ADDRESS,
                    context: { chainName },
                },
            ];
        }

        if (!sheetRecoveryAddress) return [];

        const validate = createRecoveryAddressValidator(
            chainDetails.caip2ChainId[chainName],
            {
                chainName,
                isNewChain,
                onChainRecoveryAddress,
                sheetRecoveryAddress,
            },
        );
        return validate();
    }

    return {
        validateRecoveryAddresses,
        validateKnownChains,
        validateUniqueAccounts,
    };
}

export function createRecoveryAddressValidator(
    chainId,
    { chainName, isNewChain, onChainRecoveryAddress, sheetRecoveryAddress },
) {
    const mismatchWarning = {
        code: $.RECOVERY_ADDRESS_MISMATCH,
        context: { chainName, onChainRecoveryAddress, sheetRecoveryAddress },
    };

    function validateEvmRecoveryAddress() {
        try {
            const sheetAddress = getAddress(sheetRecoveryAddress);
            if (isNewChain) return [];

            return getAddress(onChainRecoveryAddress) === sheetAddress
                ? []
                : [mismatchWarning];
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

    function validateNonEvmRecoveryAddress() {
        return isNewChain || onChainRecoveryAddress === sheetRecoveryAddress
            ? []
            : [mismatchWarning];
    }

    return chainId?.startsWith("eip155:")
        ? validateEvmRecoveryAddress
        : validateNonEvmRecoveryAddress;
}

function findDuplicateAccountAddresses(accounts) {
    const addresses = accounts.map(({ accountAddress }) => accountAddress);
    const duplicateIndexes = findDuplicateIndexes(addresses);
    return [...new Set([...duplicateIndexes].map((index) => addresses[index]))];
}
