"""
NFT Blockchain Service
Handles NFT minting and management on blockchain
Interacts with NFTShareCertificate.sol
"""
from typing import Dict, Any
from decimal import Decimal
import logging

logger = logging.getLogger('nft')


class NFTBlockchainService:
    """
    Blockchain service for NFT operations
    """
    
    def __init__(self, blockchain_client):
        """
        Initialize with blockchain client
        
        Args:
            blockchain_client: Instance of BlockchainClient from blockchain app
        """
        self.client = blockchain_client
    
    def mint_nft_certificate(
        self,
        investor_address: str,
        campaign_id: str,
        investment_amount: str,
        metadata_uri: str = ""
    ) -> Dict[str, Any]:
        """
        Mint NFT share certificate for investor
        
        Args:
            investor_address: Investor's wallet address
            campaign_id: Campaign UUID
            investment_amount: Investment amount in ETH
            metadata_uri: IPFS URI for NFT metadata
            
        Returns:
            Dict with txHash, tokenId, blockNumber, gasUsed
        """
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            voting_weight = self._calculate_voting_weight(investment_amount)
            
            tx = contract.functions.mintCertificate(
                investor_address,
                campaign_id,
                int(Decimal(investment_amount) * Decimal('1e18')),
                voting_weight,
                metadata_uri
            )
            
            result = self.client.send_transaction(tx)
            
            receipt = self.client.w3.eth.get_transaction_receipt(result['txHash'])
            token_id = self._parse_mint_event(receipt, contract)
            
            result['tokenId'] = token_id
            
            logger.info(
                f"NFT minted for {investor_address}, Token ID: {token_id}, "
                f"TX: {result['txHash']}"
            )
            return result
            
        except Exception as e:
            logger.error(f"Failed to mint NFT: {e}")
            raise
    
    def _calculate_voting_weight(self, investment_amount: str) -> int:
        """Calculate voting weight: 1 vote per 1000 ETB"""
        amount = Decimal(investment_amount)
        return int(amount / Decimal('1000'))
    
    def _parse_mint_event(self, receipt, nft_contract):
        """Parse CertificateMinted event from transaction receipt"""
        try:
            event = nft_contract.events.CertificateMinted()
            logs = event.process_receipt(receipt)
            
            if logs and len(logs) > 0:
                return str(logs[0]['args']['tokenId'])
            
            raise ValueError("CertificateMinted event not found in receipt")
            
        except Exception as e:
            logger.error(f"Failed to parse token ID: {e}")
            raise
    
    def get_nft_metadata(self, token_id: str) -> Dict[str, Any]:
        """Get NFT metadata from blockchain"""
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            cert = contract.functions.certificates(int(token_id)).call()
            token_uri = contract.functions.tokenURI(int(token_id)).call()
            
            return {
                'tokenId': token_id,
                'investor': cert[0],
                'campaignId': cert[1],
                'investmentAmount': cert[2],
                'votingWeight': cert[3],
                'mintedAt': cert[4],
                'isValid': cert[5],
                'tokenURI': token_uri
            }
            
        except Exception as e:
            logger.error(f"Failed to get NFT metadata: {e}")
            return {}
    
    def get_investor_certificates(self, investor_address: str) -> list:
        """Get all NFT certificates owned by investor"""
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            balance = contract.functions.balanceOf(investor_address).call()
            
            certificates = []
            for i in range(balance):
                token_id = contract.functions.tokenOfOwnerByIndex(
                    investor_address,
                    i
                ).call()
                
                cert_data = self.get_nft_metadata(str(token_id))
                certificates.append(cert_data)
            
            return certificates
            
        except Exception as e:
            logger.error(f"Failed to get investor certificates: {e}")
            return []
    
    def transfer_nft(
        self,
        from_address: str,
        to_address: str,
        token_id: str
    ) -> Dict[str, Any]:
        """
        Transfer NFT certificate to new owner
        
        Args:
            from_address: Current owner's address
            to_address: New owner's address
            token_id: NFT token ID
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            tx = contract.functions.transferFrom(
                from_address,
                to_address,
                int(token_id)
            )
            
            result = self.client.send_transaction(tx)
            
            logger.info(
                f"NFT #{token_id} transferred from {from_address} to {to_address}, "
                f"TX: {result['txHash']}"
            )
            return result
            
        except Exception as e:
            logger.error(f"Failed to transfer NFT: {e}")
            raise
    
    def revoke_certificate(self, token_id: str) -> Dict[str, Any]:
        """
        Revoke NFT certificate (admin function)
        
        Args:
            token_id: NFT token ID to revoke
            
        Returns:
            Dict with txHash, blockNumber, gasUsed
        """
        try:
            contract = self.client.get_contract_instance('nft_certificate')
            
            tx = contract.functions.revokeCertificate(int(token_id))
            
            result = self.client.send_transaction(tx)
            
            logger.info(f"NFT #{token_id} revoked, TX: {result['txHash']}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to revoke NFT: {e}")
            raise
