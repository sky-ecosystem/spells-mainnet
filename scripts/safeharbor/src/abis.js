export const AGREEMENTV2_RAW_ABI_MAP = {
    addChains: "addChains(tuple(string, tuple(string, uint8)[], uint256)[])",
    setChains:
        "setChains(uint256[], tuple(string, tuple(string, uint8)[], uint256)[])",
    removeChain: "removeChain(uint256)",
    addAccounts: "addAccounts(uint256, tuple(string, uint8)[])",
    setAccounts: "setAccounts(uint256, uint256[], tuple(string, uint8)[])",
    removeAccount: "removeAccount(uint256, uint256)",
};

export const AGREEMENTV2_ABI = [
    "function getDetails() view returns (tuple(string protocolName, tuple(string name, string contact)[] contactDetails, tuple(string assetRecoveryAddress, tuple(string accountAddress, uint8 childContractScope)[] accounts, uint256 id)[] chains, tuple(uint256 bountyPercentage, uint256 bountyCapUSD, bool retainable, uint8 identity, string diligenceRequirements) bountyTerms, string agreementURI))",
    "function addChains(tuple(string assetRecoveryAddress, tuple(string accountAddress, uint8 childContractScope)[] accounts, uint256 id)[] chains)",
    "function setChains(uint256[] chainIds, tuple(string assetRecoveryAddress, tuple(string accountAddress, uint8 childContractScope)[] accounts, uint256 id)[] chains)",
    "function removeChain(uint256 chainId)",
    "function addAccounts(uint256 chainId, tuple(string accountAddress, uint8 childContractScope)[] accounts)",
    "function setAccounts(uint256 chainId, uint256[] accountIds, tuple(string accountAddress, uint8 childContractScope)[] accounts)",
    "function removeAccount(uint256 chainId, uint256 accountId)",
];
