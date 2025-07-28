import {
    createProvider,
    createContractInstances,
} from "./utils/contractUtils.js";
import { AGREEMENT_ADDRESS } from "./constants.js";

export async function fetchOnChainState() {
    try {
        // Initialize provider and contract instances
        const provider = createProvider();
        const { agreement } = createContractInstances(provider);

        // Fetch all details in a single call
        const details = await agreement.getDetails();

        // Log the complete state
        console.log("\nRegistry State:");
        console.log(
            JSON.stringify(
                {
                    agreementAddress: AGREEMENT_ADDRESS,
                    protocolName: details.protocolName,
                    contactDetails: details.contactDetails,
                    chains: details.chains,
                    bountyTerms: details.bountyTerms,
                    agreementURI: details.agreementURI,
                },
                null,
                2,
            ),
        );

        return details;
    } catch (error) {
        console.error("Error fetching registry state:", error);
        throw error;
    }
}

// Only run if this file is being executed directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
    fetchRegistryState();
}

