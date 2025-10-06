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
        calldatas[${index}] = "${update.calldata}";`;
    });

    solidityCode += `

        _doSaferHarborUpdates(calldatas);
    `;

    return solidityCode.trim();
}

function getDescription(update) {
    if (update.function === "addAccounts") {
        return `AddAccounts - Adding ${update.args[1].length} account(s) to chain ${update.args[0]}`;
    } else if (update.function === "removeAccounts") {
        return `RemoveAccounts for chain ${update.args[0]} with ${update.args[1].length} accounts`;
    } else if (update.function === "addChains") {
        let chains = "";
        for (const chain of update.args[0]) {
            chains += `${chain.caip2ChainId}(${chain.accounts.length} accounts) `;
        }
        return `AddChains for chains ${chains}`;
    } else if (update.function === "removeChains") {
        let chains = "";
        update.args[0].forEach((chain, index) => {
            chains += `${index == 0 ? "" : ", "}${chain}`;
        });

        return `RemoveChains for chains ${chains}`;
    }
}
