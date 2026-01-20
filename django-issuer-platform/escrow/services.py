"""
Escrow Blockchain Service
Handles fund release and refund operations on blockchain
Interacts with FundEscrow.sol and CampaignImplementation.sol
"""
from typing import Dict, Any, List
from decimal import Decimal
from web3 import Web3
import logging

logger = logging.getLogger('escrow')


class EscrowBlockchainService:
    """
    Blockchain service for escrow operations
    """
    
    def __init__(self, blockchain_client):
        """
        Initialize with blockchain client
        
        Args:
            blockchain_client: Instance of BlockchainClient from blockchain app
        """
        self.client = blockchain_client
    
    def release_funds(
        self,
        campaign_address: str,
        recipient_address: str
    ) -> Dict[str, Any]:
        """
        Release escrowed funds to campaign issuer
        Called when campaign is successful
        
        Args:
            campaign_address: Campaign contract address
            recipient_address: Issuer's wallet address
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            recipient = Web3.to_checksum_address(recipient_address)
            
            tx = contract.functions.releaseFunds(recipient)
            
            result = self.client.send_transaction(tx)
            
            logger.info(
                f"Funds released from {campaign_address} to {recipient_address}, "
                f"TX: {result['txHash']}"
            )
            return result
            
        except Exception as e:
            logger.error(f"Failed to release funds: {e}")
            raise
    
    def initiate_refund(self, campaign_address: str) -> Dict[str, Any]:
        """
        Initiate refund process for failed campaign
        
        Args:
            campaign_address: Campaign contract address
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            tx = contract.functions.initiateRefund()
            
            result = self.client.send_transaction(tx)
            
            logger.info(f"Refund initiated for campaign {campaign_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to initiate refund: {e}")
            raise
    
    def process_investor_refund(
        self,
        campaign_address: str,
        investor_address: str
    ) -> Dict[str, Any]:
        """
        Process refund for individual investor
        
        Args:
            campaign_address: Campaign contract address
            investor_address: Investor wallet address
            
        Returns:
            Dict with txHash, blockNumber, gasUsed, refundAmount
        """
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            investor = Web3.to_checksum_address(investor_address)
            
            contribution_wei = contract.functions.contributions(investor).call()
            
            tx = contract.functions.refund(investor)
            
            result = self.client.send_transaction(tx)
            result['refundAmount'] = Web3.from_wei(contribution_wei, 'ether')
            
            logger.info(
                f"Refund processed for {investor_address} from {campaign_address}, "
                f"Amount: {result['refundAmount']} ETH"
            )
            return result
            
        except Exception as e:
            logger.error(f"Failed to process refund: {e}")
            raise
    
    def get_escrow_balance(self, campaign_address: str) -> Decimal:
        """Get current escrow balance for campaign"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            balance_wei = self.client.w3.eth.get_balance(contract_address)
            return Decimal(str(Web3.from_wei(balance_wei, 'ether')))
            
        except Exception as e:
            logger.error(f"Failed to get escrow balance: {e}")
            return Decimal('0')
    
    def get_refund_status(
        self,
        campaign_address: str,
        investor_address: str
    ) -> Dict[str, Any]:
        """Check refund status for investor"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            investor = Web3.to_checksum_address(investor_address)
            
            refunded = contract.functions.refunded(investor).call()
            contribution = contract.functions.contributions(investor).call()
            
            return {
                'investor': investor_address,
                'hasBeenRefunded': refunded,
                'contributionAmount': Web3.from_wei(contribution, 'ether')
            }
            
        except Exception as e:
            logger.error(f"Failed to get refund status: {e}")
            return {}
