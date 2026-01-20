"""
Escrow Module Signals
Automatically handles fund release and refund based on campaign status
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from campaigns_module.models import Campaign
from .models import FundEscrow
import logging

logger = logging.getLogger('escrow')


@receiver(post_save, sender=Campaign)
def handle_campaign_completion(sender, instance, created, **kwargs):
    """
    Handle fund release or refund when campaign completes
    
    - If successful: Release funds to issuer
    - If failed/cancelled: Initiate refunds to investors
    """
    if not hasattr(instance, 'escrow'):
        return
    
    escrow = instance.escrow
    
    if instance.status == 'successful' and escrow.can_release_funds:
        logger.info(f"Campaign {instance.title} successful, queuing fund release")
        
        from .tasks import release_funds_to_issuer
        release_funds_to_issuer.delay(str(escrow.id))
    
    elif instance.status in ['failed', 'cancelled'] and escrow.can_refund:
        logger.info(f"Campaign {instance.title} {instance.status}, queuing refunds")
        
        from .tasks import process_campaign_refunds
        process_campaign_refunds.delay(str(escrow.id))
