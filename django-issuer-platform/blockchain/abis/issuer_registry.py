"""
IssuerRegistry.sol ABI
Simplified essential functions for issuer management
"""

ISSUER_REGISTRY_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "issuer", "type": "address"},
            {"internalType": "string", "name": "vcHash", "type": "string"},
            {"internalType": "string", "name": "ipfsHash", "type": "string"}
        ],
        "name": "registerIssuer",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "issuer", "type": "address"}],
        "name": "isRegisteredIssuer",
        "outputs": [{"internalType": "bool", "name": "registered", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "issuer", "type": "address"}],
        "name": "canIssuerStartCampaign",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "", "type": "address"}],
        "name": "issuers",
        "outputs": [
            {"internalType": "string", "name": "vcHash", "type": "string"},
            {"internalType": "string", "name": "ipfsHash", "type": "string"},
            {"internalType": "uint256", "name": "registeredAt", "type": "uint256"},
            {"internalType": "bool", "name": "isActive", "type": "bool"},
            {"internalType": "uint256", "name": "lastCampaignYear", "type": "uint256"},
            {"internalType": "bool", "name": "exclusivityLock", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "string", "name": "newIpfsHash", "type": "string"}],
        "name": "updateInformationMemorandum",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "address", "name": "issuer", "type": "address"},
            {"indexed": False, "internalType": "string", "name": "vcHash", "type": "string"},
            {"indexed": False, "internalType": "string", "name": "ipfsHash", "type": "string"},
            {"indexed": False, "internalType": "uint256", "name": "timestamp", "type": "uint256"}
        ],
        "name": "IssuerRegistered",
        "type": "event"
    }
]
