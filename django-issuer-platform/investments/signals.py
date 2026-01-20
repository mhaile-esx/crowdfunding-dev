"""
Django signals for investment-blockchain synchronization
Implements dual-ledger sync for investments
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Investment
import logging

logger = logging.getLogger('investments')


@receiver(post_save, sender=Investment)
def sync_investment_to_blockchain(sender, instance, created, **kwargs):
    """
    Sync investment to blockchain when confirmed
    """
    if instance.status == 'confirmed' and not instance.blockchain_tx_hash:
        if not instance.campaign.smart_contract_address:
            logger.warning(
                f"Cannot record investment {instance.id}: "
                f"campaign {instance.campaign.id} not deployed"
            )
            return

        logger.info(f"Queuing blockchain recording for investment {instance.id}")

        try:
            from .tasks import record_investment_on_blockchain
            record_investment_on_blockchain.delay(str(instance.id))
            logger.info(f"Blockchain recording queued for investment {instance.id}")
        except Exception as e:
            logger.warning(f"Could not queue blockchain task for investment {instance.id}: {e}")
            # Investment still saved - blockchain sync can be retried later
