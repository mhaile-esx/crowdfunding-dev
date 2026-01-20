"""
CampaignFactory.sol ABI
Essential functions for campaign deployment
"""

CAMPAIGN_FACTORY_ABI = [
    {
        "inputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "string", "name": "companyName", "type": "string"},
            {"internalType": "string", "name": "description", "type": "string"},
            {"internalType": "uint256", "name": "fundingGoal", "type": "uint256"},
            {"internalType": "uint256", "name": "duration", "type": "uint256"},
            {"internalType": "string", "name": "documentHash", "type": "string"}
        ],
        "name": "createCampaign",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "creator", "type": "address"}],
        "name": "getCampaignsByCreator",
        "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getAllCampaigns",
        "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "string", "name": "", "type": "string"}],
        "name": "campaignIdToAddress",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": False, "internalType": "address", "name": "campaignAddress", "type": "address"},
            {"indexed": True, "internalType": "address", "name": "creator", "type": "address"},
            {"indexed": False, "internalType": "string", "name": "campaignId", "type": "string"},
            {"indexed": False, "internalType": "string", "name": "companyName", "type": "string"},
            {"indexed": False, "internalType": "uint256", "name": "fundingGoal", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "deadline", "type": "uint256"}
        ],
        "name": "CampaignCreated",
        "type": "event"
    }
]
