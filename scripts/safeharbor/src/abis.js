export const AGREEMENTV2_ABI = [
    {
        type: "constructor",
        inputs: [
            {
                name: "_details",
                type: "tuple",
                internalType: "struct AgreementDetailsV2",
                components: [
                    {
                        name: "protocolName",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "contactDetails",
                        type: "tuple[]",
                        internalType: "struct Contact[]",
                        components: [
                            {
                                name: "name",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "contact",
                                type: "string",
                                internalType: "string",
                            },
                        ],
                    },
                    {
                        name: "chains",
                        type: "tuple[]",
                        internalType: "struct Chain[]",
                        components: [
                            {
                                name: "assetRecoveryAddress",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "accounts",
                                type: "tuple[]",
                                internalType: "struct Account[]",
                                components: [
                                    {
                                        name: "accountAddress",
                                        type: "string",
                                        internalType: "string",
                                    },
                                    {
                                        name: "childContractScope",
                                        type: "uint8",
                                        internalType: "enum ChildContractScope",
                                    },
                                ],
                            },
                            {
                                name: "caip2ChainId",
                                type: "string",
                                internalType: "string",
                            },
                        ],
                    },
                    {
                        name: "bountyTerms",
                        type: "tuple",
                        internalType: "struct BountyTerms",
                        components: [
                            {
                                name: "bountyPercentage",
                                type: "uint256",
                                internalType: "uint256",
                            },
                            {
                                name: "bountyCapUSD",
                                type: "uint256",
                                internalType: "uint256",
                            },
                            {
                                name: "retainable",
                                type: "bool",
                                internalType: "bool",
                            },
                            {
                                name: "identity",
                                type: "uint8",
                                internalType: "enum IdentityRequirements",
                            },
                            {
                                name: "diligenceRequirements",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "aggregateBountyCapUSD",
                                type: "uint256",
                                internalType: "uint256",
                            },
                        ],
                    },
                    {
                        name: "agreementURI",
                        type: "string",
                        internalType: "string",
                    },
                ],
            },
            {
                name: "_registry",
                type: "address",
                internalType: "address",
            },
            {
                name: "_owner",
                type: "address",
                internalType: "address",
            },
        ],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "addAccounts",
        inputs: [
            {
                name: "_caip2ChainId",
                type: "string",
                internalType: "string",
            },
            {
                name: "_accounts",
                type: "tuple[]",
                internalType: "struct Account[]",
                components: [
                    {
                        name: "accountAddress",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "childContractScope",
                        type: "uint8",
                        internalType: "enum ChildContractScope",
                    },
                ],
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "addChains",
        inputs: [
            {
                name: "_chains",
                type: "tuple[]",
                internalType: "struct Chain[]",
                components: [
                    {
                        name: "assetRecoveryAddress",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "accounts",
                        type: "tuple[]",
                        internalType: "struct Account[]",
                        components: [
                            {
                                name: "accountAddress",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "childContractScope",
                                type: "uint8",
                                internalType: "enum ChildContractScope",
                            },
                        ],
                    },
                    {
                        name: "caip2ChainId",
                        type: "string",
                        internalType: "string",
                    },
                ],
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "getDetails",
        inputs: [],
        outputs: [
            {
                name: "",
                type: "tuple",
                internalType: "struct AgreementDetailsV2",
                components: [
                    {
                        name: "protocolName",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "contactDetails",
                        type: "tuple[]",
                        internalType: "struct Contact[]",
                        components: [
                            {
                                name: "name",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "contact",
                                type: "string",
                                internalType: "string",
                            },
                        ],
                    },
                    {
                        name: "chains",
                        type: "tuple[]",
                        internalType: "struct Chain[]",
                        components: [
                            {
                                name: "assetRecoveryAddress",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "accounts",
                                type: "tuple[]",
                                internalType: "struct Account[]",
                                components: [
                                    {
                                        name: "accountAddress",
                                        type: "string",
                                        internalType: "string",
                                    },
                                    {
                                        name: "childContractScope",
                                        type: "uint8",
                                        internalType: "enum ChildContractScope",
                                    },
                                ],
                            },
                            {
                                name: "caip2ChainId",
                                type: "string",
                                internalType: "string",
                            },
                        ],
                    },
                    {
                        name: "bountyTerms",
                        type: "tuple",
                        internalType: "struct BountyTerms",
                        components: [
                            {
                                name: "bountyPercentage",
                                type: "uint256",
                                internalType: "uint256",
                            },
                            {
                                name: "bountyCapUSD",
                                type: "uint256",
                                internalType: "uint256",
                            },
                            {
                                name: "retainable",
                                type: "bool",
                                internalType: "bool",
                            },
                            {
                                name: "identity",
                                type: "uint8",
                                internalType: "enum IdentityRequirements",
                            },
                            {
                                name: "diligenceRequirements",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "aggregateBountyCapUSD",
                                type: "uint256",
                                internalType: "uint256",
                            },
                        ],
                    },
                    {
                        name: "agreementURI",
                        type: "string",
                        internalType: "string",
                    },
                ],
            },
        ],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "owner",
        inputs: [],
        outputs: [
            {
                name: "",
                type: "address",
                internalType: "address",
            },
        ],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "removeAccounts",
        inputs: [
            {
                name: "_caip2ChainId",
                type: "string",
                internalType: "string",
            },
            {
                name: "_accountAddresses",
                type: "string[]",
                internalType: "string[]",
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "removeChains",
        inputs: [
            {
                name: "_caip2ChainIds",
                type: "string[]",
                internalType: "string[]",
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "renounceOwnership",
        inputs: [],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "setBountyTerms",
        inputs: [
            {
                name: "_bountyTerms",
                type: "tuple",
                internalType: "struct BountyTerms",
                components: [
                    {
                        name: "bountyPercentage",
                        type: "uint256",
                        internalType: "uint256",
                    },
                    {
                        name: "bountyCapUSD",
                        type: "uint256",
                        internalType: "uint256",
                    },
                    {
                        name: "retainable",
                        type: "bool",
                        internalType: "bool",
                    },
                    {
                        name: "identity",
                        type: "uint8",
                        internalType: "enum IdentityRequirements",
                    },
                    {
                        name: "diligenceRequirements",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "aggregateBountyCapUSD",
                        type: "uint256",
                        internalType: "uint256",
                    },
                ],
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "setChains",
        inputs: [
            {
                name: "_chains",
                type: "tuple[]",
                internalType: "struct Chain[]",
                components: [
                    {
                        name: "assetRecoveryAddress",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "accounts",
                        type: "tuple[]",
                        internalType: "struct Account[]",
                        components: [
                            {
                                name: "accountAddress",
                                type: "string",
                                internalType: "string",
                            },
                            {
                                name: "childContractScope",
                                type: "uint8",
                                internalType: "enum ChildContractScope",
                            },
                        ],
                    },
                    {
                        name: "caip2ChainId",
                        type: "string",
                        internalType: "string",
                    },
                ],
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "setContactDetails",
        inputs: [
            {
                name: "_contactDetails",
                type: "tuple[]",
                internalType: "struct Contact[]",
                components: [
                    {
                        name: "name",
                        type: "string",
                        internalType: "string",
                    },
                    {
                        name: "contact",
                        type: "string",
                        internalType: "string",
                    },
                ],
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "setProtocolName",
        inputs: [
            {
                name: "_protocolName",
                type: "string",
                internalType: "string",
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "transferOwnership",
        inputs: [
            {
                name: "newOwner",
                type: "address",
                internalType: "address",
            },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "event",
        name: "AgreementUpdated",
        inputs: [],
        anonymous: false,
    },
    {
        type: "event",
        name: "OwnershipTransferred",
        inputs: [
            {
                name: "previousOwner",
                type: "address",
                indexed: true,
                internalType: "address",
            },
            {
                name: "newOwner",
                type: "address",
                indexed: true,
                internalType: "address",
            },
        ],
        anonymous: false,
    },
    {
        type: "error",
        name: "AccountNotFound",
        inputs: [],
    },
    {
        type: "error",
        name: "AccountNotFoundByAddress",
        inputs: [
            {
                name: "caip2ChainId",
                type: "string",
                internalType: "string",
            },
            {
                name: "accountAddress",
                type: "string",
                internalType: "string",
            },
        ],
    },
    {
        type: "error",
        name: "CannotSetBothAggregateBountyCapUSDAndRetainable",
        inputs: [],
    },
    {
        type: "error",
        name: "ChainNotFound",
        inputs: [],
    },
    {
        type: "error",
        name: "ChainNotFoundByCaip2Id",
        inputs: [
            {
                name: "caip2ChainId",
                type: "string",
                internalType: "string",
            },
        ],
    },
    {
        type: "error",
        name: "DuplicateChainId",
        inputs: [
            {
                name: "caip2ChainId",
                type: "string",
                internalType: "string",
            },
        ],
    },
    {
        type: "error",
        name: "InvalidChainId",
        inputs: [
            {
                name: "caip2ChainId",
                type: "string",
                internalType: "string",
            },
        ],
    },
    {
        type: "error",
        name: "OwnableInvalidOwner",
        inputs: [
            {
                name: "owner",
                type: "address",
                internalType: "address",
            },
        ],
    },
    {
        type: "error",
        name: "OwnableUnauthorizedAccount",
        inputs: [
            {
                name: "account",
                type: "address",
                internalType: "address",
            },
        ],
    },
];
