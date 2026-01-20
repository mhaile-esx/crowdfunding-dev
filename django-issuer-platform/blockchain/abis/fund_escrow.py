"""
FundEscrow.sol ABI
Essential functions for fund management
"""

FUND_ESCROW_ABI = [
    {
        "inputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "address", "name": "issuer", "type": "address"},
            {"internalType": "address", "name": "investor", "type": "address"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "depositFunds",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "string", "name": "campaignId", "type": "string"}],
        "name": "releaseFunds",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "address", "name": "investor", "type": "address"}
        ],
        "name": "processRefund",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "string", "name": "", "type": "string"}],
        "name": "escrowAccounts",
        "outputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "address", "name": "issuer", "type": "address"},
            {"internalType": "uint256", "name": "totalFunds", "type": "uint256"},
            {"internalType": "uint256", "name": "yieldGenerated", "type": "uint256"},
            {"internalType": "bool", "name": "fundsReleased", "type": "bool"},
            {"internalType": "bool", "name": "refundInitiated", "type": "bool"},
            {"internalType": "uint256", "name": "createdAt", "type": "uint256"},
            {"internalType": "uint256", "name": "releasedAt", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": False, "internalType": "string", "name": "campaignId", "type": "string"},
            {"indexed": True, "internalType": "address", "name": "investor", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "totalEscrow", "type": "uint256"}
        ],
        "name": "FundsDeposited",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": False, "internalType": "string", "name": "campaignId", "type": "string"},
            {"indexed": True, "internalType": "address", "name": "issuer", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "principalAmount", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "yieldAmount", "type": "uint256"}
        ],
        "name": "FundsReleased",
        "type": "event"
    }
]
