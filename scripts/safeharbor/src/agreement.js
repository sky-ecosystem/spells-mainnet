import { DIAGNOSTIC_CODES as $ } from "./diagnosticCodes.js";
import { Contract } from "ethers";
import { AGREEMENT_V3_ABI } from "./abis.js";
import { getChainlogAddress } from "./chainlog.js";

export function createAgreementReader({ provider }) {
    return async function getAgreementDetails() {
        const address = await getChainlogAddress(
            provider,
            AGREEMENT_CHAINLOG_KEY,
        );
        const agreementInstance = new Contract(
            address,
            AGREEMENT_V3_ABI,
            provider,
        );
        return agreementInstance.getDetails();
    };
}

export function normalizeOnchainState(details, chainDetails) {
    const validationWarnings = [];
    const onChainState = details.chains.reduce((chains, chain) => {
        const chainName = chainDetails.name[chain.caip2ChainId];

        if (!chainName) {
            validationWarnings.push({
                code: $.UNKNOWN_ONCHAIN_CHAIN,
                context: { chainId: chain.caip2ChainId },
            });
            return chains;
        }

        chains[chainName] = {
            accounts: chain.accounts.map((account) => ({
                accountAddress: account[0],
                childContractScope: account[1],
            })),
            assetRecoveryAddress: chain.assetRecoveryAddress,
        };
        return chains;
    }, {});

    return { onChainState, validationWarnings };
}

const AGREEMENT_CHAINLOG_KEY = "SAFE_HARBOR_AGREEMENT";
