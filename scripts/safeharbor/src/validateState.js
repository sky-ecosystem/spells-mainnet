import { getAddress } from "ethers";

export function validateState(onChainState, csvState, chainDetails) {
    const { validateRecoveryAddresses, validateKnownChains } =
        createStateValidators(onChainState, csvState, chainDetails);

    return [...validateRecoveryAddresses(), ...validateKnownChains()];
}

export function createStateValidators(onChainState, csvState, chainDetails) {
    function validateRecoveryAddresses() {
        return Object.keys(onChainState)
            .filter((chainName) => Object.hasOwn(csvState, chainName))
            .flatMap(validateRecoveryAddress);
    }

    function validateKnownChains() {
        return Object.keys(csvState)
            .filter(
                (chainName) =>
                    !Object.hasOwn(chainDetails.caip2ChainId, chainName),
            )
            .map(
                (chainName) =>
                    `\n\n⚠️-----⚠️ \nUnknown chain details in CSV: name='${chainName}' \nInclude chain details to the chain details tab in the Google Sheet to add coverage to it. \n⚠️-----⚠️\n\n`,
            );
    }

    function validateRecoveryAddress(chainName) {
        const onchainRecoveryAddress =
            onChainState[chainName].assetRecoveryAddress;
        const csvRecoveryAddress = chainDetails.assetRecoveryAddress[chainName];

        if (!onchainRecoveryAddress || !csvRecoveryAddress) return [];

        const validate = createRecoveryAddressValidator(
            chainDetails.caip2ChainId[chainName],
            { chainName, onchainRecoveryAddress, csvRecoveryAddress },
        );
        return validate();
    }

    return { validateRecoveryAddresses, validateKnownChains };
}

export function createRecoveryAddressValidator(
    chainId,
    { chainName, onchainRecoveryAddress, csvRecoveryAddress },
) {
    const mismatchWarning = `\n\n‼️-----‼️ \nAsset Recovery Address mismatch for chain '${chainName}'. \nOn-chain: ${onchainRecoveryAddress} \nCSV:      ${csvRecoveryAddress} \n‼️-----‼️\n\n`;

    function validateEvmRecoveryAddress() {
        try {
            return getAddress(onchainRecoveryAddress) ===
                getAddress(csvRecoveryAddress)
                ? []
                : [mismatchWarning];
        } catch {
            return [
                `⚠️ Invalid EVM Asset Recovery Address for chain '${chainName}'. On-chain: ${onchainRecoveryAddress}; CSV: ${csvRecoveryAddress}`,
            ];
        }
    }

    function validateNonEvmRecoveryAddress() {
        return onchainRecoveryAddress === csvRecoveryAddress
            ? []
            : [mismatchWarning];
    }

    return chainId?.startsWith("eip155:")
        ? validateEvmRecoveryAddress
        : validateNonEvmRecoveryAddress;
}
