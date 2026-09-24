import { decodeBase58, encodeBase58, getAddress, isAddress, isHexString, toBeHex } from "ethers";
import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { findDuplicateIndexes } from "../utils/findDuplicateIndexes.js";

export function normalizeOnChainState({ chains }) {
    const value = normalizeChains(chains);
    return {
        value,
        warnings: [
            ...validateUniqueAccounts(value),
            ...validateEquivalentEvmAccounts(value),
            ...validateRecoveryAddresses(value),
        ],
    };
}

function normalizeChains(chains) {
    return Object.fromEntries(
        chains.map(({ caip2ChainId, accounts, assetRecoveryAddress }) => [
            caip2ChainId,
            {
                accounts: accounts.map(([accountAddress, childContractScope]) => ({
                    accountAddress,
                    childContractScope,
                })),
                assetRecoveryAddress,
            },
        ]),
    );
}

function validateUniqueAccounts(agreementOnChainState) {
    return Object.entries(agreementOnChainState).flatMap(([chainId, { accounts }]) => {
        const addresses = accounts.map(({ accountAddress }) => accountAddress);
        return [...findDuplicateIndexes(addresses)].map((index) => ({
            code: $.DUPLICATE_ONCHAIN_ACCOUNT,
            context: {
                chainId,
                address: addresses[index],
                firstScope: accounts[addresses.indexOf(addresses[index])].childContractScope,
                duplicateScope: accounts[index].childContractScope,
            },
        }));
    });
}

function validateEquivalentEvmAccounts(agreementOnChainState) {
    return Object.entries(agreementOnChainState).flatMap(([chainId, { accounts }]) => {
        if (!chainId.startsWith("eip155:")) {
            return [];
        }

        const firstByCanonicalAddress = new Map();
        const seenAddresses = new Set();
        return accounts.flatMap(({ accountAddress, childContractScope }) => {
            if (!isHexString(accountAddress, 20) || !isAddress(accountAddress) || seenAddresses.has(accountAddress)) {
                return [];
            }
            seenAddresses.add(accountAddress);

            const canonicalAddress = getAddress(accountAddress);
            const firstAccount = firstByCanonicalAddress.get(canonicalAddress);
            if (!firstAccount) {
                firstByCanonicalAddress.set(canonicalAddress, { accountAddress, childContractScope });
                return [];
            }
            return [
                {
                    code: $.DUPLICATE_ONCHAIN_EVM_ACCOUNT,
                    context: {
                        chainId,
                        firstAddress: firstAccount.accountAddress,
                        duplicateAddress: accountAddress,
                        firstScope: firstAccount.childContractScope,
                        duplicateScope: childContractScope,
                    },
                },
            ];
        });
    });
}

function validateRecoveryAddresses(agreementOnChainState) {
    return Object.entries(agreementOnChainState).flatMap(([chainId, { assetRecoveryAddress }]) => {
        if (hasInvalidKnownAddressFormat(assetRecoveryAddress, chainId)) {
            return [
                {
                    code: $.INVALID_ONCHAIN_RECOVERY_ADDRESS,
                    context: {
                        chainId,
                        address: assetRecoveryAddress,
                    },
                },
            ];
        }
        return [];
    });
}

function hasInvalidKnownAddressFormat(address, chainId) {
    if (chainId.startsWith("eip155:")) {
        return !isHexString(address, 20) || !isAddress(address);
    }
    if (chainId.startsWith("solana:")) {
        try {
            return encodeBase58(toBeHex(decodeBase58(address), 32)) !== address;
        } catch {
            return true;
        }
    }
    // Unsupported namespaces are diagnosed during reconciliation, not as malformed addresses.
    return false;
}
