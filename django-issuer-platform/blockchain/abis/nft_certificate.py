"""
NFTShareCertificate.sol ABI
Essential functions for NFT minting
"""

NFT_CERTIFICATE_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "to", "type": "address"},
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "string", "name": "companyName", "type": "string"},
            {"internalType": "uint256", "name": "investmentAmount", "type": "uint256"},
            {"internalType": "uint256", "name": "shareCount", "type": "uint256"},
            {"internalType": "string", "name": "tokenURI", "type": "string"}
        ],
        "name": "issueCertificate",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "owner", "type": "address"}],
        "name": "ownerCertificates",
        "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "certificates",
        "outputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "string", "name": "companyName", "type": "string"},
            {"internalType": "uint256", "name": "investmentAmount", "type": "uint256"},
            {"internalType": "uint256", "name": "shareCount", "type": "uint256"},
            {"internalType": "uint256", "name": "votingPower", "type": "uint256"},
            {"internalType": "uint256", "name": "issuedAt", "type": "uint256"},
            {"internalType": "bool", "name": "isActive", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
        "name": "tokenURI",
        "outputs": [{"internalType": "string", "name": "", "type": "string"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": False, "internalType": "uint256", "name": "tokenId", "type": "uint256"},
            {"indexed": True, "internalType": "address", "name": "owner", "type": "address"},
            {"indexed": False, "internalType": "string", "name": "campaignId", "type": "string"},
            {"indexed": False, "internalType": "uint256", "name": "investmentAmount", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "shareCount", "type": "uint256"}
        ],
        "name": "CertificateIssued",
        "type": "event"
    }
]
