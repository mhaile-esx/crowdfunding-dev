"""
Investment Blockchain Service
Handles investment recording on blockchain
"""
from typing import Dict, Any
from decimal import Decimal
from web3 import Web3
import logging

logger = logging.getLogger('investments')


class InvestmentBlockchainService:
    """
    Blockchain service for investment operations
    Records investments on campaign smart contracts
    """
    
    def __init__(self, blockchain_client):
        """
        Initialize with blockchain client
        
        Args:
            blockchain_client: Instance of BlockchainClient from blockchain app
        """
        self.client = blockchain_client
    
    def record_investment(
        self,
        campaign_address: str,
        investor_address: str,
        amount: str
    ) -> Dict[str, Any]:
        """
        Record investment on campaign smart contract
        
        Args:
            campaign_address: Campaign contract address
            investor_address: Investor wallet address
            amount: Investment amount in ETH
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            amount_wei = Web3.to_wei(Decimal(amount), 'ether')
            
            tx = contract.functions.invest(investor_address, amount_wei)
            
            result = self.client.send_transaction(tx)
            
            logger.info(
                f"Investment recorded: {investor_address} → {campaign_address}: "
                f"{amount} ETH, TX: {result['txHash']}"
            )
            return result
            
        except Exception as e:
            logger.error(f"Failed to record investment: {e}")
            raise
    
    def get_investor_contribution(
        self,
        campaign_address: str,
        investor_address: str
    ) -> Decimal:
        """Get investor's contribution amount from blockchain"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            contribution_wei = contract.functions.contributions(investor_address).call()
            return Decimal(str(Web3.from_wei(contribution_wei, 'ether')))
            
        except Exception as e:
            logger.error(f"Failed to get contribution: {e}")
            return Decimal('0')
