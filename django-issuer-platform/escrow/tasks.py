"""
Escrow Module Celery Tasks
Async blockchain operations for fund management
"""
from celery import shared_task
from django.utils import timezone
from decimal import Decimal
import logging

logger = logging.getLogger('escrow')


@shared_task(bind=True, max_retries=3)
def release_funds_to_issuer(self, escrow_id: str):
    """
    Release escrowed funds to campaign issuer (successful campaign)
    
    Args:
        escrow_id: UUID of fund escrow record
        
    Updates:
        - funds_released = True
        - funds_released_at
        - release_tx_hash
        - status = 'released'
    """
    try:
        from .models import FundEscrow
        from .services import EscrowBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        escrow = FundEscrow.objects.select_related('campaign__company').get(id=escrow_id)
        
        if escrow.funds_released:
            logger.info(f"Funds already released for escrow {escrow_id}")
            return
        
        if not escrow.campaign.smart_contract_address:
            raise ValueError("Campaign not deployed to blockchain")
        
        logger.info(f"Releasing funds for campaign: {escrow.campaign.title}")
        
        client = get_blockchain_client()
        service = EscrowBlockchainService(client)
        
        result = service.release_funds(
            campaign_address=escrow.campaign.smart_contract_address,
            recipient_address=escrow.campaign.company.wallet_address
        )
        
        escrow.funds_released = True
        escrow.funds_released_at = timezone.now()
        escrow.release_tx_hash = result['txHash']
        escrow.released_to_address = escrow.campaign.company.wallet_address
        escrow.status = 'released'
        escrow.save()
        
        campaign = escrow.campaign
        campaign.funds_released = True
        campaign.funds_released_at = timezone.now()
        campaign.funds_release_tx_hash = result['txHash']
        campaign.save()
        
        logger.info(
            f"Funds released successfully for {escrow.campaign.title}, "
            f"TX: {result['txHash']}"
        )
        
        return {
            'success': True,
            'escrow_id': escrow_id,
            'tx_hash': result['txHash'],
            'recipient': escrow.released_to_address
        }
        
    except Exception as e:
        logger.error(f"Failed to release funds for escrow {escrow_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def process_refunds(self, escrow_id: str):
    """Alias for process_campaign_refunds"""
    return process_campaign_refunds.delay(escrow_id)


@shared_task(bind=True, max_retries=3)
def process_campaign_refunds(self, escrow_id: str):
    """
    Process refunds for failed/cancelled campaign
    Initiates refunds for all investors
    
    Args:
        escrow_id: UUID of fund escrow record
    """
    try:
        from .models import FundEscrow, RefundTransaction
        from .services import EscrowBlockchainService
        from blockchain.web3_client import get_blockchain_client
        from investments.models import Investment
        
        escrow = FundEscrow.objects.select_related('campaign').get(id=escrow_id)
        
        if escrow.refund_completed:
            logger.info(f"Refunds already completed for escrow {escrow_id}")
            return
        
        if not escrow.campaign.smart_contract_address:
            raise ValueError("Campaign not deployed to blockchain")
        
        logger.info(f"Processing refunds for campaign: {escrow.campaign.title}")
        
        client = get_blockchain_client()
        service = EscrowBlockchainService(client)
        
        if not escrow.refund_initiated:
            initiate_result = service.initiate_refund(
                campaign_address=escrow.campaign.smart_contract_address
            )
            
            escrow.refund_initiated = True
            escrow.refund_tx_hash = initiate_result['txHash']
            escrow.save()
            
            logger.info(f"Refund initiated, TX: {initiate_result['txHash']}")
        
        investments = Investment.objects.filter(
            campaign=escrow.campaign,
            status='confirmed'
        )
        
        refund_count = 0
        for investment in investments:
            try:
                refund_result = service.process_investor_refund(
                    campaign_address=escrow.campaign.smart_contract_address,
                    investor_address=investment.user.wallet_address
                )
                
                RefundTransaction.objects.create(
                    escrow=escrow,
                    investor=investment.user,
                    amount=investment.amount,
                    tx_hash=refund_result['txHash']
                )
                
                investment.status = 'refunded'
                investment.refunded_at = timezone.now()
                investment.save()
                
                refund_count += 1
                
                logger.info(
                    f"Refund processed for {investment.user.username}: "
                    f"{investment.amount} ETB"
                )
                
            except Exception as e:
                logger.error(f"Failed to refund investment {investment.id}: {e}")
                continue
        
        escrow.refund_completed = True
        escrow.refunded_at = timezone.now()
        escrow.status = 'refunded'
        escrow.save()
        
        logger.info(
            f"Refunds completed for {escrow.campaign.title}, "
            f"Processed {refund_count} refunds"
        )
        
        return {
            'success': True,
            'escrow_id': escrow_id,
            'refunds_processed': refund_count
        }
        
    except Exception as e:
        logger.error(f"Failed to process refunds for escrow {escrow_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task
def sync_escrow_balance_from_blockchain(escrow_id: str):
    """
    Sync escrow balance from blockchain
    Useful for verification and reconciliation
    """
    try:
        from .models import FundEscrow
        from .services import EscrowBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        escrow = FundEscrow.objects.select_related('campaign').get(id=escrow_id)
        
        if not escrow.campaign.smart_contract_address:
            logger.warning(f"Campaign not deployed, cannot sync escrow balance")
            return
        
        client = get_blockchain_client()
        service = EscrowBlockchainService(client)
        
        balance = service.get_escrow_balance(escrow.campaign.smart_contract_address)
        
        escrow.total_escrowed = balance
        escrow.save()
        
        logger.info(f"Escrow balance synced: {balance} ETH for escrow {escrow_id}")
        
        return {
            'success': True,
            'escrow_id': escrow_id,
            'balance': str(balance)
        }
        
    except Exception as e:
        logger.error(f"Failed to sync escrow balance {escrow_id}: {e}")
        raise
