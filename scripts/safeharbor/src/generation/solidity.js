export function generateSolidity(updates) {
    if (updates.length === 0) {
        return "";
    }

    return [
        `bytes[] memory calldatas = new bytes[](${updates.length});`,
        ...updates.map(
            (update, index) =>
                `// ${escapeCommentLineTerminators(getDescription(update))}\ncalldatas[${index}] = hex'${update.calldata.slice(2)}';`,
        ),
        "_updateSafeHarbor(calldatas);",
    ]
        .join("\n\n")
        .split("\n")
        .map((line) => line.trim())
        .join("\n");
}

function escapeCommentLineTerminators(description) {
    // Solidity ends // comments at any of these seven Unicode line terminators.
    return description.replace(
        /[\n\v\f\r\u0085\u2028\u2029]/g,
        (character) => `\\u${character.charCodeAt(0).toString(16).padStart(4, "0")}`,
    );
}

function getDescription(update) {
    switch (update.fn) {
        case "removeChains": {
            return `Remove chains: ${update.args[0].join(", ")}`;
        }
        case "addChains": {
            return update.args[0]
                .map(
                    (chainInfo) =>
                        `Add new ${chainInfo.caip2ChainId} with recovery address ${chainInfo.assetRecoveryAddress} and accounts: ${listAccountAddresses(chainInfo.accounts)}`,
                )
                .join("; ");
        }
        case "removeAccounts": {
            return `Remove accounts from ${update.args[0]} chain: ${update.args[1].join(", ")}`;
        }
        case "addAccounts": {
            return `Add accounts to ${update.args[0]} chain: ${listAccountAddresses(update.args[1])}`;
        }
        default:
            throw new Error("Unknown update");
    }
}

function listAccountAddresses(accounts) {
    return accounts.map((account) => account.accountAddress).join(", ");
}
