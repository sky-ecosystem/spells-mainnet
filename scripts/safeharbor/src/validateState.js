import { getAddress } from "ethers";
import { findDuplicateIndexes } from "./utils/findDuplicateIndexes.js";

export function validateState(onChainState, csvState, chainDetails) {
    const {
        validateRecoveryAddresses,
        validateKnownChains,
        validateUniqueAccounts,
    } = createStateValidators(onChainState, csvState, chainDetails);

    return [
        ...validateRecoveryAddresses(),
        ...validateKnownChains(),
        ...validateUniqueAccounts(),
    ];
}

export function createStateValidators(onChainState, csvState, chainDetails) {
    function validateUniqueAccounts() {
        return [
            ...Object.keys(csvState).flatMap(validateCsvAccounts),
            ...Object.keys(onChainState).flatMap(validateOnChainAccounts),
        ];
    }

    function validateCsvAccounts(chainName) {
        return findDuplicateAccountAddresses(csvState[chainName]).map(
            (address) =>
                `Duplicate account address in CSV state for chain '${chainName}': ${address}`,
        );
    }

    function validateOnChainAccounts(chainName) {
        return findDuplicateAccountAddresses(
            onChainState[chainName].accounts,
        ).map(
            (address) =>
                `Duplicate account address in on-chain state for chain '${chainName}': ${address}`,
        );
    }

    function validateRecoveryAddresses() {
        return Object.keys(csvState).flatMap(validateRecoveryAddress);
    }

    function validateKnownChains() {
        return Object.keys(csvState)
            .filter(
                (chainName) =>
                    !Object.hasOwn(chainDetails.caip2ChainId, chainName),
            )
            .map(
                (chainName) =>
                    `Unknown chain details in CSV: name='${chainName}'\nInclude chain details to the chain details tab in the Google Sheet to add coverage to it.`,
            );
    }

    function validateRecoveryAddress(chainName) {
        const isNewChain = !Object.hasOwn(onChainState, chainName);
        const onchainRecoveryAddress =
            onChainState[chainName]?.assetRecoveryAddress;
        const csvRecoveryAddress = chainDetails.assetRecoveryAddress[chainName];

        if (!isNewChain && !onchainRecoveryAddress) {
            return [
                `Missing on-chain Asset Recovery Address for existing chain '${chainName}'`,
            ];
        }

        if (!csvRecoveryAddress) return [];

        const validate = createRecoveryAddressValidator(
            chainDetails.caip2ChainId[chainName],
            {
                chainName,
                isNewChain,
                onchainRecoveryAddress,
                csvRecoveryAddress,
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

function findDuplicateAccountAddresses(accounts) {
    const addresses = accounts.map(({ accountAddress }) => accountAddress);
    const duplicateIndexes = findDuplicateIndexes(addresses);
    return [...new Set([...duplicateIndexes].map((index) => addresses[index]))];
}

export function createRecoveryAddressValidator(
    chainId,
    { chainName, isNewChain, onchainRecoveryAddress, csvRecoveryAddress },
) {
    const mismatchWarning = `Asset Recovery Address mismatch for chain '${chainName}'.\nOn-chain: ${onchainRecoveryAddress}\nCSV:      ${csvRecoveryAddress}`;

    function validateEvmRecoveryAddress() {
        try {
            const csvAddress = getAddress(csvRecoveryAddress);
            if (isNewChain) return [];

            return getAddress(onchainRecoveryAddress) === csvAddress
                ? []
                : [mismatchWarning];
        } catch {
            return [
                `Invalid EVM Asset Recovery Address for chain '${chainName}'. On-chain: ${isNewChain ? "not registered" : onchainRecoveryAddress}; CSV: ${csvRecoveryAddress}`,
            ];
        }
    }

    function validateNonEvmRecoveryAddress() {
        return isNewChain || onchainRecoveryAddress === csvRecoveryAddress
            ? []
            : [mismatchWarning];
    }

    return chainId?.startsWith("eip155:")
        ? validateEvmRecoveryAddress
        : validateNonEvmRecoveryAddress;
}
