import { DIAGNOSTIC_CODES as $ } from "../diagnostic/index.js";
import { findDuplicateIndexes } from "../utils/findDuplicateIndexes.js";

export function normalizeOnChainState(agreementDetails) {
    const value = normalizeChains(agreementDetails.chains);
    return { value, warnings: validateUniqueAccounts(value) };
}

function normalizeChains(chains) {
    return Object.fromEntries(chains.map((chain) => [chain.caip2ChainId, normalizeChain(chain)]));
}

function normalizeChain(chain) {
    return {
        accounts: chain.accounts.map(normalizeAccount),
        assetRecoveryAddress: chain.assetRecoveryAddress,
    };
}

function normalizeAccount(account) {
    return { accountAddress: account[0], childContractScope: account[1] };
}

function validateUniqueAccounts(agreementOnChainState) {
    return Object.entries(agreementOnChainState).flatMap(([chainId, { accounts }]) =>
        validateChainAccounts(chainId, accounts),
    );
}

function validateChainAccounts(chainId, accounts) {
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
}
