"""
Campaign Blockchain Service
Handles campaign deployment and management on blockchain
Interacts with CampaignFactory.sol and CampaignImplementation.sol
"""
from typing import Dict, Any
from decimal import Decimal
from web3 import Web3
import logging

logger = logging.getLogger('campaigns_module')


class CampaignBlockchainService:
    """
    Blockchain service for campaign operations
    """
    
    def __init__(self, blockchain_client):
        """
        Initialize with blockchain client
        
        Args:
            blockchain_client: Instance of BlockchainClient from blockchain app
        """
        self.client = blockchain_client
    
    def deploy_campaign(
        self,
        campaign_id: str,
        company_name: str,
        description: str,
        funding_goal: str,
        duration_days: int,
        document_hash: str
    ) -> Dict[str, Any]:
        """
        Deploy new campaign to blockchain via CampaignFactory.sol
        
        Args:
            campaign_id: UUID of campaign
            company_name: Company name
            description: Campaign description
            funding_goal: Funding goal in ETH
            duration_days: Campaign duration in days
            document_hash: IPFS hash of campaign documents
            
        Returns:
            Dict with txHash, campaignAddress, blockNumber, gasUsed
        """
        try:
            contract = self.client.get_contract_instance('campaign_factory')
            
            funding_goal_wei = Web3.to_wei(Decimal(funding_goal), 'ether')
            duration_seconds = duration_days * 24 * 60 * 60
            
            tx = contract.functions.createCampaign(
                campaign_id,
                company_name,
                description,
                funding_goal_wei,
                duration_seconds,
                document_hash
            )
            
            result = self.client.send_transaction(tx)
            
            receipt = self.client.w3.eth.get_transaction_receipt(result['txHash'])
            campaign_address = self._parse_campaign_created_event(receipt, contract)
            
            result['campaignAddress'] = campaign_address
            
            logger.info(f"Campaign deployed: {campaign_id} at {campaign_address}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to deploy campaign: {e}")
            raise
    
    def _parse_campaign_created_event(self, receipt, factory_contract):
        """Parse CampaignCreated event from transaction receipt"""
        try:
            event = factory_contract.events.CampaignCreated()
            logs = event.process_receipt(receipt)
            
            if logs and len(logs) > 0:
                return logs[0]['args']['campaignAddress']
            
            raise ValueError("CampaignCreated event not found in receipt")
            
        except Exception as e:
            logger.error(f"Failed to parse campaign address: {e}")
            raise
    
    def get_campaign_info(self, campaign_address: str) -> Dict[str, Any]:
        """Get campaign information from blockchain"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            campaign_data = contract.functions.getCampaignDetails().call()
            
            return {
                'id': campaign_data[0],
                'company': campaign_data[1],
                'description': campaign_data[2],
                'fundingGoal': campaign_data[3],
                'currentFunding': campaign_data[4],
                'endTime': campaign_data[5],
                'isActive': campaign_data[6],
                'documentHash': campaign_data[7],
            }
            
        except Exception as e:
            logger.error(f"Failed to get campaign info: {e}")
            return {}
    
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
            
            logger.info(f"Investment recorded: {investor_address} → {campaign_address}: {amount} ETH")
            return result
            
        except Exception as e:
            logger.error(f"Failed to record investment: {e}")
            raise
    
    def get_campaign_investors(self, campaign_address: str) -> list:
        """Get list of campaign investors from blockchain"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            return contract.functions.getInvestors().call()
            
        except Exception as e:
            logger.error(f"Failed to get investors: {e}")
            return []
    
    def get_investor_contribution(
        self,
        campaign_address: str,
        investor_address: str
    ) -> int:
        """Get investor's contribution amount"""
        try:
            contract_address = Web3.to_checksum_address(campaign_address)
            contract = self.client.w3.eth.contract(
                address=contract_address,
                abi=self.client._get_abi('campaign_implementation')
            )
            
            contribution_wei = contract.functions.contributions(investor_address).call()
            return Web3.from_wei(contribution_wei, 'ether')
            
        except Exception as e:
            logger.error(f"Failed to get contribution: {e}")
            return 0
