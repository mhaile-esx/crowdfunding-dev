"""
Campaign Module Signals
Implements dual-ledger synchronization for campaigns
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Campaign
import logging

logger = logging.getLogger('campaigns_module')


@receiver(post_save, sender=Campaign)
def sync_campaign_to_blockchain(sender, instance, created, **kwargs):
    """
    Automatically deploy approved campaigns to blockchain
    
    Dual-ledger pattern:
    1. Campaign saved to PostgreSQL (source of truth)
    2. If approved and not deployed, trigger blockchain deployment
    3. Celery task updates PostgreSQL with contract address
    """
    if instance.can_deploy_to_blockchain():
        logger.info(f"Queuing blockchain deployment for campaign: {instance.title}")
        
        from .tasks import deploy_campaign_to_blockchain
        
        deploy_campaign_to_blockchain.delay(str(instance.id))
        
        logger.info(f"Blockchain deployment queued for campaign: {instance.id}")
