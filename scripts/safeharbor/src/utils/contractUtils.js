import { ethers } from "ethers";
import {
    FACTORY_ADDRESS,
    OWNER_ADDRESS,
    PROTOCOL_NAME,
    CONTACT_DETAILS,
    BOUNTY_TERMS,
    AGREEMENT_URI,
    AGREEMENT_ADDRESS,
} from "../constants.js";
import { FACTORY_ABI, AGREEMENTV2_ABI as AGREEMENT_ABI } from "../abis.js";
import { getAssetRecoveryAddress, getChainId } from "./chainUtils.js";

// Create a provider instance
export function createProvider() {
    if (!process.env.ETH_RPC_URL) {
        throw new Error("ETH_RPC_URL environment variable is not set");
    }
    return new ethers.providers.JsonRpcProvider(process.env.ETH_RPC_URL);
}

export function createEmptyDetails() {
    return {
        protocolName: PROTOCOL_NAME,
        contactDetails: [CONTACT_DETAILS],
        chains: [], // Empty chains array
        bountyTerms: BOUNTY_TERMS,
        agreementURI: AGREEMENT_URI,
    };
}

export function createContractInstances(provider) {
    const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, provider);
    const agreement = new ethers.Contract(
        AGREEMENT_ADDRESS,
        AGREEMENT_ABI,
        provider,
    );
    return { factory, agreement };
}

export function generateCreatePayload(factory, emptyDetails) {
    const createCalldata = factory.interface.encodeFunctionData("create", [
        emptyDetails,
        OWNER_ADDRESS,
    ]);

    return {
        target: FACTORY_ADDRESS,
        calldata: createCalldata,
    };
}

export function generateAddChainsPayload(agreement, csvState) {
    const allChains = Object.entries(csvState).map(([chain, accounts]) => ({
        assetRecoveryAddress: getAssetRecoveryAddress(chain),
        accounts: accounts.map((acc) => ({
            accountAddress: acc.accountAddress,
            childContractScope: acc.childContractScope,
        })),
        id: getChainId(chain),
    }));

    const addChainsCalldata = agreement.interface.encodeFunctionData(
        "addChains",
        [allChains],
    );
    return {
        target: AGREEMENT_ADDRESS,
        calldata: addChainsCalldata,
    };
}

export function logConfiguration(emptyDetails, allChains) {
    console.log("\nConfiguration used:");
    console.log("Protocol Name:", emptyDetails.protocolName);
    console.log("\nChains and Accounts:");
    allChains.forEach((chain) => {
        console.log(`\nChain ID: ${chain.id}`);
        chain.accounts.forEach((account) => {
            console.log(
                `  - ${account.accountAddress} (Factory: ${account.childContractScope === 3})`,
            );
        });
    });
}
