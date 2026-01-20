"""
NFT Module Signals
Automatically mints NFT certificates for successful investments
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from campaigns_module.models import Campaign
import logging

logger = logging.getLogger('nft')


@receiver(post_save, sender=Campaign)
def mint_nfts_for_successful_campaign(sender, instance, created, **kwargs):
    """
    Automatically mint NFT certificates when campaign is successful
    
    Called when campaign status changes to 'successful'
    Mints NFT for all confirmed investments
    """
    if instance.status == 'successful':
        logger.info(f"Campaign {instance.title} successful, queuing NFT minting")
        
        from .tasks import mint_nfts_for_campaign
        mint_nfts_for_campaign.delay(str(instance.id))
        
        logger.info(f"NFT minting queued for campaign {instance.id}")
