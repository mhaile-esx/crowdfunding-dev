"""
NFT Certificate Metadata Generation Service
Generates rich metadata for investor NFT share certificates with issuer branding
"""
import json
import hashlib
from datetime import datetime
from decimal import Decimal
from django.conf import settings


class NFTMetadataGenerator:
    """
    Generates ERC721 metadata for share certificates
    Includes issuer logo, name, description, and investment details
    """
    
    IPFS_GATEWAY = getattr(settings, 'IPFS_SETTINGS', {}).get('GATEWAY_URL', 'https://ipfs.io/ipfs/')
    
    @classmethod
    def generate_certificate_metadata(
        cls,
        investment,
        token_id: int,
        share_count: int = None,
        equity_percentage: float = None
    ) -> dict:
        """
        Generate complete NFT metadata for a share certificate
        
        Args:
            investment: Investment model instance
            token_id: The NFT token ID
            share_count: Number of shares (calculated if not provided)
            equity_percentage: Equity percentage (calculated if not provided)
            
        Returns:
            dict: ERC721-compatible metadata
        """
        campaign = investment.campaign
        company = campaign.company
        investor = investment.user
        
        # Calculate share count if not provided (1 share per 1000 ETB)
        if share_count is None:
            share_count = int(float(investment.amount) / 1000) or 1
        
        # Calculate equity percentage if not provided
        if equity_percentage is None:
            if campaign.funding_goal and float(campaign.funding_goal) > 0:
                equity_percentage = (float(investment.amount) / float(campaign.funding_goal)) * 100
            else:
                equity_percentage = 0
        
        # Calculate voting power (1 vote per 1000 ETB)
        voting_power = int(float(investment.amount) / 1000) or 1
        
        # Build issuer info
        issuer_info = cls._build_issuer_info(company)
        
        # Build certificate attributes
        attributes = cls._build_attributes(
            campaign=campaign,
            company=company,
            investment=investment,
            share_count=share_count,
            equity_percentage=equity_percentage,
            voting_power=voting_power
        )
        
        # Generate unique certificate ID
        certificate_id = cls._generate_certificate_id(
            token_id=token_id,
            campaign_id=str(campaign.id),
            investor_address=investor.wallet_address or str(investor.id)
        )
        
        # Build complete metadata
        metadata = {
            "name": f"{company.name} Share Certificate #{token_id}",
            "description": cls._generate_description(campaign, company, investment, share_count),
            "image": cls._get_certificate_image(company, campaign),
            "external_url": f"https://crowdfundchain.com/certificates/{certificate_id}",
            
            # Issuer branding
            "issuer": issuer_info,
            
            # Certificate details
            "certificate_id": certificate_id,
            "token_id": token_id,
            "campaign_id": str(campaign.id),
            "campaign_title": campaign.title,
            
            # Investment details
            "investment": {
                "amount": str(investment.amount),
                "currency": "ETB",
                "date": investment.created_at.isoformat() if investment.created_at else datetime.now().isoformat(),
                "transaction_hash": investment.blockchain_tx_hash or investment.transaction_hash,
            },
            
            # Ownership
            "shares": share_count,
            "equity_percentage": round(equity_percentage, 4),
            "voting_power": voting_power,
            
            # ERC721 standard attributes
            "attributes": attributes,
            
            # Metadata
            "created_at": datetime.now().isoformat(),
            "platform": "CrowdfundChain",
            "network": "Polygon Edge",
            "chain_id": getattr(settings, 'BLOCKCHAIN_SETTINGS', {}).get('CHAIN_ID', 100),
        }
        
        return metadata
    
    @classmethod
    def _build_issuer_info(cls, company) -> dict:
        """Build issuer information block"""
        logo_url = getattr(company, "logo_url", "") or ""

        logo_ipfs_hash = getattr(company, "logo_ipfs_hash", None)
        if logo_ipfs_hash:
            logo_url = f"{cls.IPFS_GATEWAY}{logo_ipfs_hash}"

        name = getattr(company, "name", "Unknown")
        
        return {
            "name": name,
            "logo": logo_url,
            "description": getattr(company, "description", "") or name,
            "sector": getattr(company, "sector", "Other"),
            "tin": getattr(company, "tin_number", "") or getattr(company, "tin", ""),
            "registration_year": getattr(company, "registration_year", None),
            "website": getattr(company, "website", "") or "",
            "verified": getattr(company, "verified", False) or getattr(company, "is_kyb_verified", False),
            "blockchain_address": getattr(company, "blockchain_address", "") or getattr(company, "wallet_address", "") or "",
        }

    @classmethod
    def _build_attributes(
        cls,
        campaign,
        company,
        investment,
        share_count: int,
        equity_percentage: float,
        voting_power: int
    ) -> list:
        """Build ERC721 attributes array"""
        return [
            {"trait_type": "Issuer", "value": company.name},
            {"trait_type": "Sector", "value": getattr(company, 'sector', 'General')},
            {"trait_type": "Campaign", "value": campaign.title},
            {"trait_type": "Investment Amount", "value": str(investment.amount), "display_type": "number"},
            {"trait_type": "Currency", "value": "ETB"},
            {"trait_type": "Shares", "value": share_count, "display_type": "number"},
            {"trait_type": "Equity Percentage", "value": round(equity_percentage, 4), "display_type": "number"},
            {"trait_type": "Voting Power", "value": voting_power, "display_type": "number"},
            {"trait_type": "Investment Date", "value": investment.created_at.strftime("%Y-%m-%d") if investment.created_at else datetime.now().strftime("%Y-%m-%d")},
            {"trait_type": "Verified Issuer", "value": "Yes" if getattr(company, "verified", False) else "No"},
            {"trait_type": "Certificate Type", "value": "Share Certificate"},
            {"trait_type": "Platform", "value": "CrowdfundChain"},
        ]
    
    @classmethod
    def _generate_description(cls, campaign, company, investment, share_count: int) -> str:
        """Generate human-readable certificate description"""
        return (
            f"This NFT Share Certificate represents ownership of {share_count} shares in "
            f"{company.name}'s '{campaign.title}' crowdfunding campaign. "
            f"Investment amount: {investment.amount:,.2f} ETB. "
            f"Sector: {getattr(company, 'sector', 'General')}. "
            f"This certificate grants voting rights in the CrowdfundChain DAO governance system. "
            f"Issued by CrowdfundChain - Blockchain-powered crowdfunding for African SMEs."
        )
    
    @classmethod
    def _get_certificate_image(cls, company, campaign) -> str:
        """Get the image URL for the certificate"""
        # Priority: Company logo > Campaign image > Default certificate image
        logo_ipfs_hash = getattr(company, "logo_ipfs_hash", None)
        if logo_ipfs_hash:
            return f"{cls.IPFS_GATEWAY}{logo_ipfs_hash}"
        if getattr(company, "logo_url", None):
            return getattr(company, "logo_url", None)
        if hasattr(campaign, 'image_url') and campaign.image_url:
            return campaign.image_url
        # Default certificate image
        return "https://crowdfundchain.com/assets/certificate-default.png"
    
    @classmethod
    def _generate_certificate_id(cls, token_id: int, campaign_id: str, investor_address: str) -> str:
        """Generate unique certificate ID"""
        data = f"{token_id}:{campaign_id}:{investor_address}"
        return hashlib.sha256(data.encode()).hexdigest()[:16].upper()
    
    @classmethod
    def to_json(cls, metadata: dict) -> str:
        """Convert metadata to JSON string"""
        return json.dumps(metadata, indent=2, default=str)
    
    @classmethod
    def generate_token_uri_data(cls, metadata: dict) -> str:
        """
        Generate base64-encoded data URI for on-chain storage
        (For when IPFS is not available)
        """
        import base64
        json_str = cls.to_json(metadata)
        encoded = base64.b64encode(json_str.encode()).decode()
        return f"data:application/json;base64,{encoded}"
