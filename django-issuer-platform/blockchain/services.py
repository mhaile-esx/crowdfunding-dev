"""
Blockchain service layer for issuer and campaign management
Mirrors the functionality from server/services/blockchain-service.ts
"""
from typing import Dict, Any, Optional
from decimal import Decimal
from web3 import Web3
from .web3_client import get_blockchain_client
import logging

logger = logging.getLogger('blockchain')


class IssuerBlockchainService:
    """
    Service for issuer registration and management on blockchain
    Interacts with IssuerRegistry.sol smart contract
    """
    
    def __init__(self):
        self.client = get_blockchain_client()
    
    def register_issuer(
        self,
        issuer_address: str,
        vc_hash: str,
        ipfs_hash: str
    ) -> Dict[str, Any]:
        """
        Register issuer on blockchain
        
        Args:
            issuer_address: Ethereum address of the issuer
            vc_hash: Keycloak Verifiable Credential hash
            ipfs_hash: IPFS hash of Information Memorandum
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract = self.client.get_contract_instance('issuer_registry')
            
            # Call registerIssuer function
            tx = contract.functions.registerIssuer(
                issuer_address,
                vc_hash,
                ipfs_hash
            )
            
            result = self.client.send_transaction(tx)
            
            logger.info(f"Issuer registered: {issuer_address}, TX: {result['txHash']}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to register issuer: {e}")
            raise
    
    def is_issuer_registered(self, issuer_address: str) -> bool:
        """Check if issuer is registered on blockchain"""
        try:
            contract = self.client.get_contract_instance('issuer_registry')
            return contract.functions.isRegisteredIssuer(issuer_address).call()
        except Exception as e:
            logger.error(f"Failed to check issuer status: {e}")
            return False
    
    def can_issuer_start_campaign(self, issuer_address: str) -> bool:
        """Check if issuer can start a new campaign (no exclusivity lock)"""
        try:
            contract = self.client.get_contract_instance('issuer_registry')
            return contract.functions.canIssuerStartCampaign(issuer_address).call()
        except Exception as e:
            logger.error(f"Failed to check campaign eligibility: {e}")
            return False
    
    def get_issuer_info(self, issuer_address: str) -> Dict[str, Any]:
        """Get issuer information from blockchain"""
        try:
            contract = self.client.get_contract_instance('issuer_registry')
            issuer = contract.functions.issuers(issuer_address).call()
            
            return {
                'vcHash': issuer[0],
                'ipfsHash': issuer[1],
                'registeredAt': issuer[2],
                'isActive': issuer[3],
                'lastCampaignYear': issuer[4],
                'exclusivityLock': issuer[5],
            }
        except Exception as e:
            logger.error(f"Failed to get issuer info: {e}")
            return {}
    
    def update_information_memorandum(
        self,
        issuer_address: str,
        new_ipfs_hash: str
    ) -> Dict[str, Any]:
        """Update issuer's Information Memorandum IPFS hash"""
        try:
            contract = self.client.get_contract_instance('issuer_registry')
            
            tx = contract.functions.updateInformationMemorandum(new_ipfs_hash)
            
            result = self.client.send_transaction(tx)
            
            logger.info(f"Updated IM for {issuer_address}: {new_ipfs_hash}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to update IM: {e}")
            raise


class CampaignBlockchainService:
    """
    Service for campaign deployment and management on blockchain
    Interacts with CampaignFactory.sol and CampaignImplementation.sol
    """
    
    def __init__(self):
        self.client = get_blockchain_client()
    
    def create_campaign(
        self,
        campaign_id: str,
        company_name: str,
        description: str,
        funding_goal: str,
        duration_days: int,
        document_hash: str
    ) -> Dict[str, Any]:
        """
        Deploy new campaign to blockchain
        
        Args:
            campaign_id: Unique campaign identifier
            company_name: Company name
            description: Campaign description
            funding_goal_eth: Funding goal in ETH
            duration_days: Campaign duration in days
            document_hash: IPFS hash of campaign documents
            
        Returns:
            Dict with txHash, campaignAddress, blockNumber
        """
        try:
            contract = self.client.get_contract_instance('campaign_factory')
            
            # Convert to Wei
            funding_goal_wei = Web3.to_wei(Decimal(funding_goal), 'ether')
            duration_seconds = duration_days * 24 * 60 * 60
            
            # Call createCampaign function
            tx = contract.functions.createCampaign(
                campaign_id,
                company_name,
                description,
                funding_goal_wei,
                duration_seconds,
                document_hash
            )
            
            result = self.client.send_transaction(tx)
            
            # Parse event to get campaign address
            receipt = self.client.w3.eth.get_transaction_receipt(result['txHash'])
            campaign_address = self._parse_campaign_created_event(receipt)
            
            result['campaignAddress'] = campaign_address
            
            logger.info(f"Campaign created: {campaign_id} at {campaign_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to create campaign: {e}")
            raise
    
    def _parse_campaign_created_event(self, receipt) -> str:
        """
        Parse CampaignCreated event to extract campaign address
        FIX: Properly parse event logs from receipt
        """
        try:
            contract = self.client.get_contract_instance('campaign_factory')
            
            # Parse logs to find CampaignCreated event
            for log in receipt.get('logs', []):
                try:
                    event = contract.events.CampaignCreated().process_log(log)
                    campaign_address = event['args']['campaignAddress']
                    logger.info(f"Parsed campaign address from event: {campaign_address}")
                    return campaign_address
                except:
                    continue
            
            logger.error("CampaignCreated event not found in receipt")
            raise ValueError("CampaignCreated event not found in receipt")
            
        except Exception as e:
            logger.error(f"Failed to parse CampaignCreated event: {e}")
            raise
    
    def record_investment(
        self,
        campaign_address: str,
        investor_address: str,
        amount: str,
        payment_method: str,
        transaction_ref: str
    ) -> Dict[str, Any]:
        """
        Record investment on blockchain
        
        Args:
            campaign_address: Campaign contract address
            investor_address: Investor's wallet address
            amount_eth: Investment amount in ETH
            payment_method: Payment method (crypto, telebirr, etc.)
            transaction_ref: External transaction reference
            
        Returns:
            Dict with txHash, blockNumber
        """
        try:
            # Get campaign contract instance
            contract = self.client.get_contract_instance(
                'campaign_factory',
                address=campaign_address
            )
            
            # Convert to Wei
            amount_wei = Web3.to_wei(Decimal(amount), 'ether')
            
            # For crypto payments, send value with transaction
            if payment_method == 'crypto':
                tx = contract.functions.investCrypto()
                result = self.client.send_transaction(tx, value=amount_wei)
            else:
                # For traditional payments, record without value
                tx = contract.functions.recordInvestment(
                    investor_address,
                    amount_wei,
                    payment_method,
                    transaction_ref
                )
                result = self.client.send_transaction(tx)
            
            logger.info(f"Investment recorded: {investor_address} → {campaign_address}: {amount} ETB")
            return result
            
        except Exception as e:
            logger.error(f"Failed to record investment: {e}")
            raise
    
    def release_funds(self, campaign_address: str) -> Dict[str, Any]:
        """
        Release funds to issuer (campaign reached 75%+ threshold)
        
        Args:
            campaign_address: Campaign contract address
            
        Returns:
            Dict with txHash, blockNumber
        """
        try:
            contract = self.client.get_contract_instance(
                'campaign_factory',
                address=campaign_address
            )
            
            tx = contract.functions.releaseFunds()
            result = self.client.send_transaction(tx)
            
            logger.info(f"Funds released for campaign: {campaign_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to release funds: {e}")
            raise
    
    def process_refund(self, campaign_address: str) -> Dict[str, Any]:
        """
        Process refunds for failed campaign (<75% threshold)
        
        Args:
            campaign_address: Campaign contract address
            
        Returns:
            Dict with txHash, blockNumber
        """
        try:
            contract = self.client.get_contract_instance(
                'campaign_factory',
                address=campaign_address
            )
            
            tx = contract.functions.refund()
            result = self.client.send_transaction(tx)
            
            logger.info(f"Refund processed for campaign: {campaign_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to process refund: {e}")
            raise
    
    def get_campaign_status(self, campaign_address: str) -> Dict[str, Any]:
        """Get campaign status from blockchain"""
        try:
            contract = self.client.get_contract_instance(
                'campaign_factory',
                address=campaign_address
            )
            
            total_raised = contract.functions.totalRaised().call()
            funding_goal = contract.functions.fundingGoal().call()
            investor_count = contract.functions.investors().call()
            deadline = contract.functions.deadline().call()
            completed = contract.functions.completed().call()
            
            return {
                'totalRaised': Web3.from_wei(total_raised, 'ether'),
                'fundingGoal': Web3.from_wei(funding_goal, 'ether'),
                'investorCount': len(investor_count) if isinstance(investor_count, list) else investor_count,
                'deadline': deadline,
                'completed': completed,
                'progressPercentage': (total_raised / funding_goal * 100) if funding_goal > 0 else 0,
            }
        except Exception as e:
            logger.error(f"Failed to get campaign status: {e}")
            return {}


class NFTCertificateService:
    """
    Service for NFT Share Certificate minting and management
    Interacts with NFTShareCertificate.sol
    """
    
    def __init__(self):
        self.client = get_blockchain_client()
    
    def mint_certificate(
        self,
        investor_address: str,
        campaign_id: str,
        company_name: str,
        investment_amount_eth: str,
        share_count: int,
        token_uri: str
    ) -> Dict[str, Any]:
        """
        Mint NFT share certificate for investor
        
        Args:
            investor_address: Investor's wallet address
            campaign_id: Campaign identifier
            company_name: Company name
            investment_amount_eth: Investment amount in ETH
            share_count: Number of shares
            token_uri: Metadata URI for NFT
            
        Returns:
            Dict with txHash, tokenId, blockNumber
        """
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            # Convert to Wei
            investment_wei = Web3.to_wei(Decimal(investment_amount_eth), 'ether')
            
            # Call issueCertificate function
            tx = contract.functions.issueCertificate(
                investor_address,
                campaign_id,
                company_name,
                investment_wei,
                share_count,
                token_uri
            )
            
            result = self.client.send_transaction(tx)
            
            # Parse event to get token ID
            receipt = self.client.w3.eth.get_transaction_receipt(result['txHash'])
            token_id = self._parse_certificate_issued_event(receipt)
            
            result['tokenId'] = token_id
            
            logger.info(f"NFT certificate minted: Token ID {token_id} for {investor_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to mint certificate: {e}")
            raise
    
    def _parse_certificate_issued_event(self, receipt) -> str:
        """Parse CertificateIssued event to extract token ID"""
        # Simplified - in production, decode event logs properly
        return "1"  # Placeholder
    
    def get_investor_certificates(self, investor_address: str) -> list:
        """Get all NFT certificates owned by investor"""
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            certificates = contract.functions.ownerCertificates(investor_address).call()
            return certificates
        except Exception as e:
            logger.error(f"Failed to get certificates: {e}")
            return []
    
    def get_certificate_details(self, token_id: str) -> Dict[str, Any]:
        """Get certificate details by token ID"""
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            cert = contract.functions.certificates(token_id).call()
            
            return {
                'campaignId': cert[0],
                'companyName': cert[1],
                'investmentAmount': Web3.from_wei(cert[2], 'ether'),
                'shareCount': cert[3],
                'votingPower': cert[4],
                'issuedAt': cert[5],
                'isActive': cert[6],
            }
        except Exception as e:
            logger.error(f"Failed to get certificate details: {e}")
            return {}
