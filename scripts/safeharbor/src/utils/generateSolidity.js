// Generate solidity code from updates
export function generateSolidityCode(updates) {
    if (updates.length === 0) {
        return "";
    }

    let solidityCode = `
        // ---------- Bug Bounty Updates ----------
        bytes[] memory calldatas = new bytes[](${updates.length});`;

    updates.forEach((update, index) => {
        solidityCode += `

        // ${getDescription(update)}
        calldatas[${index}] = hex'${update.calldata.replace(/^0x/, "")}';`;
    });

    solidityCode += `

        _updateSafeHarbor(calldatas);
    `;

    return solidityCode.trimEnd();
}

function getDescription(update) {
    switch (update.function) {
        case "removeChains": {
            // Extracts and lists all chains to be removed.
            const chains = update.args[0].join(", ");
            return `Remove chains: ${chains}`;
        }
        case "addChains": {
            // Describes adding contracts to new chains, listing addresses for each.
            const descriptions = update.args[0].map((chainInfo) => {
                if (chainInfo.accounts.length === 0) {
                    return `Add new ${chainInfo.caip2ChainId} with recovery address ${chainInfo.assetRecoveryAddress} and no accounts`;
                }
                const accounts = chainInfo.accounts
                    .map((acc) => acc.accountAddress)
                    .join(", ");
                return `Add new ${chainInfo.caip2ChainId} with recovery address ${chainInfo.assetRecoveryAddress} and accounts: ${accounts}`;
            });
            return descriptions.join("; ");
        }
        case "removeAccounts": {
            // Lists accounts to be removed from a specific chain.
            const chain = update.args[0];
            const accounts = update.args[1].join(", ");
            return `Remove accounts from ${chain} chain: ${accounts}`;
        }
        case "addAccounts": {
            // Lists accounts to be added to a specific chain.
            const chain = update.args[0];
            const accounts = update.args[1]
                .map((acc) => acc.accountAddress)
                .join(", ");
            return `Add accounts to ${chain} chain: ${accounts}`;
        }
        default:
            throw new Error("Unknown update");
    }
}
