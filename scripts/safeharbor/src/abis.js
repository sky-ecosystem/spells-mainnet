export const AGREEMENT_V3_ABI = [
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "string",
                        name: "protocolName",
                        type: "string",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "name",
                                type: "string",
                            },
                            {
                                internalType: "string",
                                name: "contact",
                                type: "string",
                            },
                        ],
                        internalType: "struct Contact[]",
                        name: "contactDetails",
                        type: "tuple[]",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "assetRecoveryAddress",
                                type: "string",
                            },
                            {
                                components: [
                                    {
                                        internalType: "string",
                                        name: "accountAddress",
                                        type: "string",
                                    },
                                    {
                                        internalType: "enum ChildContractScope",
                                        name: "childContractScope",
                                        type: "uint8",
                                    },
                                ],
                                internalType: "struct Account[]",
                                name: "accounts",
                                type: "tuple[]",
                            },
                            {
                                internalType: "string",
                                name: "caip2ChainId",
                                type: "string",
                            },
                        ],
                        internalType: "struct Chain[]",
                        name: "chains",
                        type: "tuple[]",
                    },
                    {
                        components: [
                            {
                                internalType: "uint256",
                                name: "bountyPercentage",
                                type: "uint256",
                            },
                            {
                                internalType: "uint256",
                                name: "bountyCapUSD",
                                type: "uint256",
                            },
                            {
                                internalType: "bool",
                                name: "retainable",
                                type: "bool",
                            },
                            {
                                internalType: "enum IdentityRequirements",
                                name: "identity",
                                type: "uint8",
                            },
                            {
                                internalType: "string",
                                name: "diligenceRequirements",
                                type: "string",
                            },
                            {
                                internalType: "uint256",
                                name: "aggregateBountyCapUSD",
                                type: "uint256",
                            },
                        ],
                        internalType: "struct BountyTerms",
                        name: "bountyTerms",
                        type: "tuple",
                    },
                    {
                        internalType: "string",
                        name: "agreementURI",
                        type: "string",
                    },
                ],
                internalType: "struct AgreementDetails",
                name: "_details",
                type: "tuple",
            },
            {
                internalType: "address",
                name: "_chainValidator",
                type: "address",
            },
            { internalType: "address", name: "_initialOwner", type: "address" },
        ],
        stateMutability: "nonpayable",
        type: "constructor",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
            { internalType: "string", name: "accountAddress", type: "string" },
        ],
        name: "Agreement__AccountNotFoundByAddress",
        type: "error",
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "aggregateBountyCapUSD",
                type: "uint256",
            },
            { internalType: "uint256", name: "bountyCapUSD", type: "uint256" },
        ],
        name: "Agreement__AggregateBountyCapLessThanBountyCap",
        type: "error",
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "bountyPercentage",
                type: "uint256",
            },
            { internalType: "uint256", name: "maxPercentage", type: "uint256" },
        ],
        name: "Agreement__BountyPercentageExceedsMaximum",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__CannotRemoveAllAccounts",
        type: "error",
    },
    {
        inputs: [],
        name: "Agreement__CannotSetBothAggregateBountyCapUsdAndRetainable",
        type: "error",
    },
    { inputs: [], name: "Agreement__ChainIdHasZeroLength", type: "error" },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__ChainNotFoundByCaip2Id",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__DuplicateChainId",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
            { internalType: "uint256", name: "accountIndex", type: "uint256" },
        ],
        name: "Agreement__InvalidAccountAddress",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__InvalidAssetRecoveryAddress",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__InvalidChainId",
        type: "error",
    },
    {
        inputs: [
            { internalType: "uint256", name: "contactIndex", type: "uint256" },
        ],
        name: "Agreement__InvalidContactDetails",
        type: "error",
    },
    {
        inputs: [
            { internalType: "string", name: "caip2ChainId", type: "string" },
        ],
        name: "Agreement__ZeroAccountsForChainId",
        type: "error",
    },
    { inputs: [], name: "Agreement__ZeroAddress", type: "error" },
    {
        inputs: [{ internalType: "address", name: "owner", type: "address" }],
        name: "OwnableInvalidOwner",
        type: "error",
    },
    {
        inputs: [{ internalType: "address", name: "account", type: "address" }],
        name: "OwnableUnauthorizedAccount",
        type: "error",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "caip2ChainId",
                type: "string",
            },
            {
                components: [
                    {
                        internalType: "string",
                        name: "accountAddress",
                        type: "string",
                    },
                    {
                        internalType: "enum ChildContractScope",
                        name: "childContractScope",
                        type: "uint8",
                    },
                ],
                indexed: false,
                internalType: "struct Account",
                name: "account",
                type: "tuple",
            },
        ],
        name: "AccountAdded",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "caip2ChainId",
                type: "string",
            },
            {
                indexed: false,
                internalType: "string",
                name: "accountAddress",
                type: "string",
            },
        ],
        name: "AccountRemoved",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "bountyPercentage",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "bountyCapUSD",
                        type: "uint256",
                    },
                    { internalType: "bool", name: "retainable", type: "bool" },
                    {
                        internalType: "enum IdentityRequirements",
                        name: "identity",
                        type: "uint8",
                    },
                    {
                        internalType: "string",
                        name: "diligenceRequirements",
                        type: "string",
                    },
                    {
                        internalType: "uint256",
                        name: "aggregateBountyCapUSD",
                        type: "uint256",
                    },
                ],
                indexed: false,
                internalType: "struct BountyTerms",
                name: "newBountyTerms",
                type: "tuple",
            },
        ],
        name: "BountyTermsSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "caip2ChainId",
                type: "string",
            },
            {
                indexed: false,
                internalType: "string",
                name: "assetRecoveryAddress",
                type: "string",
            },
            {
                components: [
                    {
                        internalType: "string",
                        name: "accountAddress",
                        type: "string",
                    },
                    {
                        internalType: "enum ChildContractScope",
                        name: "childContractScope",
                        type: "uint8",
                    },
                ],
                indexed: false,
                internalType: "struct Account[]",
                name: "accounts",
                type: "tuple[]",
            },
        ],
        name: "ChainAdded",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "caip2ChainId",
                type: "string",
            },
        ],
        name: "ChainRemoved",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "caip2ChainId",
                type: "string",
            },
            {
                indexed: false,
                internalType: "string",
                name: "assetRecoveryAddress",
                type: "string",
            },
            {
                components: [
                    {
                        internalType: "string",
                        name: "accountAddress",
                        type: "string",
                    },
                    {
                        internalType: "enum ChildContractScope",
                        name: "childContractScope",
                        type: "uint8",
                    },
                ],
                indexed: false,
                internalType: "struct Account[]",
                name: "accounts",
                type: "tuple[]",
            },
        ],
        name: "ChainSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                components: [
                    { internalType: "string", name: "name", type: "string" },
                    { internalType: "string", name: "contact", type: "string" },
                ],
                indexed: false,
                internalType: "struct Contact[]",
                name: "newContactDetails",
                type: "tuple[]",
            },
        ],
        name: "ContactDetailsSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "previousOwner",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address",
                name: "newOwner",
                type: "address",
            },
        ],
        name: "OwnershipTransferred",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "string",
                name: "newName",
                type: "string",
            },
        ],
        name: "ProtocolNameSet",
        type: "event",
    },
    {
        inputs: [],
        name: "MAX_BOUNTY_PERCENTAGE",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "string", name: "_caip2ChainId", type: "string" },
            {
                components: [
                    {
                        internalType: "string",
                        name: "accountAddress",
                        type: "string",
                    },
                    {
                        internalType: "enum ChildContractScope",
                        name: "childContractScope",
                        type: "uint8",
                    },
                ],
                internalType: "struct Account[]",
                name: "_accounts",
                type: "tuple[]",
            },
        ],
        name: "addAccounts",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "string",
                        name: "assetRecoveryAddress",
                        type: "string",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "accountAddress",
                                type: "string",
                            },
                            {
                                internalType: "enum ChildContractScope",
                                name: "childContractScope",
                                type: "uint8",
                            },
                        ],
                        internalType: "struct Account[]",
                        name: "accounts",
                        type: "tuple[]",
                    },
                    {
                        internalType: "string",
                        name: "caip2ChainId",
                        type: "string",
                    },
                ],
                internalType: "struct Chain[]",
                name: "_chains",
                type: "tuple[]",
            },
        ],
        name: "addChains",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "string",
                        name: "assetRecoveryAddress",
                        type: "string",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "accountAddress",
                                type: "string",
                            },
                            {
                                internalType: "enum ChildContractScope",
                                name: "childContractScope",
                                type: "uint8",
                            },
                        ],
                        internalType: "struct Account[]",
                        name: "accounts",
                        type: "tuple[]",
                    },
                    {
                        internalType: "string",
                        name: "caip2ChainId",
                        type: "string",
                    },
                ],
                internalType: "struct Chain[]",
                name: "_chains",
                type: "tuple[]",
            },
        ],
        name: "addOrSetChains",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "getAgreementURI",
        outputs: [{ internalType: "string", name: "", type: "string" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getBountyTerms",
        outputs: [
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "bountyPercentage",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "bountyCapUSD",
                        type: "uint256",
                    },
                    { internalType: "bool", name: "retainable", type: "bool" },
                    {
                        internalType: "enum IdentityRequirements",
                        name: "identity",
                        type: "uint8",
                    },
                    {
                        internalType: "string",
                        name: "diligenceRequirements",
                        type: "string",
                    },
                    {
                        internalType: "uint256",
                        name: "aggregateBountyCapUSD",
                        type: "uint256",
                    },
                ],
                internalType: "struct BountyTerms",
                name: "",
                type: "tuple",
            },
        ],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getChainIds",
        outputs: [{ internalType: "string[]", name: "", type: "string[]" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getChainValidator",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getDetails",
        outputs: [
            {
                components: [
                    {
                        internalType: "string",
                        name: "protocolName",
                        type: "string",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "name",
                                type: "string",
                            },
                            {
                                internalType: "string",
                                name: "contact",
                                type: "string",
                            },
                        ],
                        internalType: "struct Contact[]",
                        name: "contactDetails",
                        type: "tuple[]",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "assetRecoveryAddress",
                                type: "string",
                            },
                            {
                                components: [
                                    {
                                        internalType: "string",
                                        name: "accountAddress",
                                        type: "string",
                                    },
                                    {
                                        internalType: "enum ChildContractScope",
                                        name: "childContractScope",
                                        type: "uint8",
                                    },
                                ],
                                internalType: "struct Account[]",
                                name: "accounts",
                                type: "tuple[]",
                            },
                            {
                                internalType: "string",
                                name: "caip2ChainId",
                                type: "string",
                            },
                        ],
                        internalType: "struct Chain[]",
                        name: "chains",
                        type: "tuple[]",
                    },
                    {
                        components: [
                            {
                                internalType: "uint256",
                                name: "bountyPercentage",
                                type: "uint256",
                            },
                            {
                                internalType: "uint256",
                                name: "bountyCapUSD",
                                type: "uint256",
                            },
                            {
                                internalType: "bool",
                                name: "retainable",
                                type: "bool",
                            },
                            {
                                internalType: "enum IdentityRequirements",
                                name: "identity",
                                type: "uint8",
                            },
                            {
                                internalType: "string",
                                name: "diligenceRequirements",
                                type: "string",
                            },
                            {
                                internalType: "uint256",
                                name: "aggregateBountyCapUSD",
                                type: "uint256",
                            },
                        ],
                        internalType: "struct BountyTerms",
                        name: "bountyTerms",
                        type: "tuple",
                    },
                    {
                        internalType: "string",
                        name: "agreementURI",
                        type: "string",
                    },
                ],
                internalType: "struct AgreementDetails",
                name: "_details",
                type: "tuple",
            },
        ],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getProtocolName",
        outputs: [{ internalType: "string", name: "", type: "string" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "owner",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "string", name: "_caip2ChainId", type: "string" },
            {
                internalType: "string[]",
                name: "_accountAddresses",
                type: "string[]",
            },
        ],
        name: "removeAccounts",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "string[]",
                name: "_caip2ChainIds",
                type: "string[]",
            },
        ],
        name: "removeChains",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "renounceOwnership",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "bountyPercentage",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "bountyCapUSD",
                        type: "uint256",
                    },
                    { internalType: "bool", name: "retainable", type: "bool" },
                    {
                        internalType: "enum IdentityRequirements",
                        name: "identity",
                        type: "uint8",
                    },
                    {
                        internalType: "string",
                        name: "diligenceRequirements",
                        type: "string",
                    },
                    {
                        internalType: "uint256",
                        name: "aggregateBountyCapUSD",
                        type: "uint256",
                    },
                ],
                internalType: "struct BountyTerms",
                name: "_bountyTerms",
                type: "tuple",
            },
        ],
        name: "setBountyTerms",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "string",
                        name: "assetRecoveryAddress",
                        type: "string",
                    },
                    {
                        components: [
                            {
                                internalType: "string",
                                name: "accountAddress",
                                type: "string",
                            },
                            {
                                internalType: "enum ChildContractScope",
                                name: "childContractScope",
                                type: "uint8",
                            },
                        ],
                        internalType: "struct Account[]",
                        name: "accounts",
                        type: "tuple[]",
                    },
                    {
                        internalType: "string",
                        name: "caip2ChainId",
                        type: "string",
                    },
                ],
                internalType: "struct Chain[]",
                name: "_chains",
                type: "tuple[]",
            },
        ],
        name: "setChains",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    { internalType: "string", name: "name", type: "string" },
                    { internalType: "string", name: "contact", type: "string" },
                ],
                internalType: "struct Contact[]",
                name: "_contactDetails",
                type: "tuple[]",
            },
        ],
        name: "setContactDetails",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "string", name: "_protocolName", type: "string" },
        ],
        name: "setProtocolName",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "newOwner", type: "address" },
        ],
        name: "transferOwnership",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
];
