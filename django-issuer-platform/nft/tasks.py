"""
NFT Module Celery Tasks
Async blockchain operations for NFT minting and management
"""
from celery import shared_task
from django.utils import timezone
from decimal import Decimal
import logging
import json

logger = logging.getLogger('nft')


@shared_task(bind=True, max_retries=3)
def mint_nft_certificate(self, investment_id: str, metadata_uri: str = ""):
    """
    Mint NFT share certificate for individual investment
    
    Args:
        investment_id: UUID of investment
        metadata_uri: Optional IPFS URI for NFT metadata
        
    Creates NFTShareCertificate record with blockchain data
    """
    try:
        from investments.models import Investment
        from .models import NFTShareCertificate
        from .services import NFTBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        investment = Investment.objects.select_related('campaign', 'user').get(id=investment_id)
        
        if hasattr(investment, 'nft_certificate'):
            logger.info(f"NFT already minted for investment {investment_id}")
            return
        
        logger.info(f"Minting NFT for investment: {investment_id}")
        
        client = get_blockchain_client()
        service = NFTBlockchainService(client)
        
        if not metadata_uri:
            metadata_uri = f"ipfs://QmExample/{investment.id}"
        
        result = service.mint_nft_certificate(
            investor_address=investment.user.wallet_address,
            campaign_id=str(investment.campaign.id),
            investment_amount=str(investment.amount),
            metadata_uri=metadata_uri
        )
        
        metadata = {
            'name': f"{investment.campaign.title} Share Certificate",
            'description': f"Ownership certificate for {investment.amount} ETB investment",
            'image': metadata_uri,
            'attributes': [
                {'trait_type': 'Campaign', 'value': investment.campaign.title},
                {'trait_type': 'Investment Amount', 'value': str(investment.amount)},
                {'trait_type': 'Voting Power', 'value': investment.voting_power},
                {'trait_type': 'Company', 'value': investment.campaign.company.name},
            ]
        }
        
        nft_cert = NFTShareCertificate.objects.create(
            owner=investment.user,
            campaign=investment.campaign,
            token_id=result['tokenId'],
            contract_address=client.get_contract_address('nft_certificate'),
            investment_amount=investment.amount,
            voting_weight=investment.voting_power,
            token_uri=metadata_uri,
            metadata=metadata,
            mint_tx_hash=result['txHash']
        )
        
        investment.nft_token_id = result['tokenId']
        investment.nft_minted = True
        investment.save()
        
        logger.info(
            f"NFT minted successfully: Token ID {result['tokenId']}, "
            f"TX: {result['txHash']}"
        )
        
        return {
            'success': True,
            'investment_id': investment_id,
            'token_id': result['tokenId'],
            'tx_hash': result['txHash']
        }
        
    except Exception as e:
        logger.error(f"Failed to mint NFT for investment {investment_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task
def mint_nfts_for_campaign(campaign_id: str):
    """
    Mint NFT certificates for all investments in successful campaign
    
    Args:
        campaign_id: UUID of successful campaign
    """
    try:
        from campaigns_module.models import Campaign
        from investments.models import Investment
        
        campaign = Campaign.objects.get(id=campaign_id)
        
        if campaign.status != 'successful':
            logger.warning(f"Campaign {campaign_id} is not successful, skipping NFT minting")
            return
        
        investments = Investment.objects.filter(
            campaign=campaign,
            status='confirmed',
            nft_minted=False
        )
        
        minted_count = 0
        for investment in investments:
            try:
                mint_nft_certificate.delay(str(investment.id))
                minted_count += 1
                
            except Exception as e:
                logger.error(f"Failed to queue NFT minting for investment {investment.id}: {e}")
                continue
        
        logger.info(
            f"Queued NFT minting for {minted_count} investments "
            f"in campaign {campaign.title}"
        )
        
        return {
            'success': True,
            'campaign_id': campaign_id,
            'queued_count': minted_count
        }
        
    except Exception as e:
        logger.error(f"Failed to mint NFTs for campaign {campaign_id}: {e}")
        raise


@shared_task(bind=True, max_retries=3)
def transfer_nft_certificate(
    self,
    nft_id: str,
    from_user_id: str,
    to_user_id: str
):
    """
    Transfer NFT certificate to new owner
    
    Args:
        nft_id: UUID of NFT certificate
        from_user_id: Current owner user ID
        to_user_id: New owner user ID
    """
    try:
        from .models import NFTShareCertificate, NFTTransferHistory
        from issuers.models import User
        from .services import NFTBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        nft = NFTShareCertificate.objects.get(id=nft_id)
        from_user = User.objects.get(id=from_user_id)
        to_user = User.objects.get(id=to_user_id)
        
        if nft.owner_id != from_user.id:
            raise ValueError(f"NFT {nft_id} does not belong to user {from_user_id}")
        
        logger.info(f"Transferring NFT #{nft.token_id} to {to_user.username}")
        
        client = get_blockchain_client()
        service = NFTBlockchainService(client)
        
        result = service.transfer_nft(
            from_address=from_user.wallet_address,
            to_address=to_user.wallet_address,
            token_id=nft.token_id
        )
        
        NFTTransferHistory.objects.create(
            nft=nft,
            from_address=from_user.wallet_address,
            to_address=to_user.wallet_address,
            transfer_tx_hash=result['txHash']
        )
        
        nft.owner = to_user
        nft.transferred = True
        nft.transfer_count += 1
        nft.save()
        
        logger.info(
            f"NFT #{nft.token_id} transferred successfully, "
            f"TX: {result['txHash']}"
        )
        
        return {
            'success': True,
            'nft_id': nft_id,
            'token_id': nft.token_id,
            'tx_hash': result['txHash']
        }
        
    except Exception as e:
        logger.error(f"Failed to transfer NFT {nft_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task
def sync_nft_ownership_from_blockchain(nft_id: str):
    """
    Sync NFT ownership from blockchain
    Useful for detecting external transfers
    """
    try:
        from .models import NFTShareCertificate
        from .services import NFTBlockchainService
        from blockchain.web3_client import get_blockchain_client
        from issuers.models import User
        
        nft = NFTShareCertificate.objects.get(id=nft_id)
        
        client = get_blockchain_client()
        service = NFTBlockchainService(client)
        
        chain_data = service.get_nft_metadata(nft.token_id)
        
        current_owner_address = chain_data.get('investor')
        
        if current_owner_address and current_owner_address.lower() != nft.owner.wallet_address.lower():
            new_owner = User.objects.filter(
                wallet_address__iexact=current_owner_address
            ).first()
            
            if new_owner:
                nft.owner = new_owner
                nft.transferred = True
                nft.transfer_count += 1
                nft.save()
                
                logger.info(
                    f"NFT #{nft.token_id} ownership updated from blockchain: "
                    f"New owner {new_owner.username}"
                )
        
        return {
            'success': True,
            'nft_id': nft_id,
            'owner': nft.owner.username
        }
        
    except Exception as e:
        logger.error(f"Failed to sync NFT ownership {nft_id}: {e}")
        raise
