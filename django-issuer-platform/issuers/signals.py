"""
Django signals for issuer-blockchain synchronization
FIX: Implements dual-ledger sync
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Company
import logging

logger = logging.getLogger('issuers')


@receiver(post_save, sender=Company)
def sync_company_to_blockchain(sender, instance, created, **kwargs):
    """
    Sync company registration to blockchain after DB save
    FIX: Triggers async blockchain registration
    
    This implements the dual-ledger pattern:
    1. Company saved to PostgreSQL (source of truth)
    2. Signal triggers async blockchain registration
    3. Celery task updates DB with blockchain data
    """
    if created and instance.user.wallet_address and not instance.registered_on_blockchain:
        logger.info(f"Queuing blockchain registration for company {instance.name}")
        
        # Import here to avoid circular dependency
        from blockchain.tasks import register_issuer_on_blockchain
        
        # Queue async blockchain registration
        register_issuer_on_blockchain.delay(str(instance.id))
        
        logger.info(f"Blockchain registration queued for company {instance.name}")
