"""
Investment Module Celery Tasks
Async blockchain operations for investments
"""
from celery import shared_task
from django.utils import timezone
from django.db import transaction
import logging

logger = logging.getLogger('investments')


@shared_task(bind=True, max_retries=3)
def record_investment_on_blockchain(self, investment_id: str):
    """
    Record investment on campaign smart contract
    
    Implements dual-ledger pattern:
    1. Investment created in PostgreSQL (source of truth)
    2. Signal triggers this Celery task
    3. Task records investment on blockchain
    4. Task updates PostgreSQL with tx hash
    5. Task updates campaign funding stats
    
    Args:
        investment_id: UUID of investment to record
        
    Updates:
        - investment.blockchain_tx_hash
        - investment.blockchain_recorded_at
        - campaign.current_funding
        - campaign.investor_count
    """
    try:
        from .models import Investment
        from campaigns_module.models import Campaign
        from .services import InvestmentBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        with transaction.atomic():
            investment = Investment.objects.select_for_update().select_related(
                'campaign', 'user'
            ).get(id=investment_id)
            
            if investment.blockchain_tx_hash:
                logger.info(f"Investment {investment_id} already recorded, skipping")
                return {
                    'success': True,
                    'already_recorded': True,
                    'tx_hash': investment.blockchain_tx_hash
                }
            
            if not investment.campaign.smart_contract_address:
                raise ValueError(
                    f"Campaign {investment.campaign.id} not deployed to blockchain"
                )
            
            logger.info(
                f"Recording investment {investment_id} on blockchain: "
                f"{investment.amount} ETB by {investment.user.username}"
            )
            
            client = get_blockchain_client()
            service = InvestmentBlockchainService(client)
            
            result = service.record_investment(
                campaign_address=investment.campaign.smart_contract_address,
                investor_address=investment.user.wallet_address,
                amount=str(investment.amount)
            )
            
            investment.blockchain_tx_hash = result['txHash']
            investment.blockchain_recorded_at = timezone.now()
            investment.save()
            
            campaign = Campaign.objects.select_for_update().get(id=investment.campaign.id)
            campaign.current_funding += investment.amount
            
            previous_confirmed_count = Investment.objects.select_for_update().filter(
                campaign=campaign,
                user=investment.user,
                status='confirmed',
                blockchain_tx_hash__isnull=False
            ).exclude(id=investment.id).count()
            
            if previous_confirmed_count == 0:
                campaign.investor_count += 1
            
            campaign.save()
            
            campaign_is_successful = campaign.is_successful
        
        investment.refresh_from_db(fields=['blockchain_tx_hash', 'blockchain_recorded_at'])
        investment.campaign.refresh_from_db()
        
        logger.info(
            f"Investment recorded successfully: {investment_id}, "
            f"TX: {result['txHash']}, Campaign successful: {campaign_is_successful}"
        )
        
        if campaign_is_successful and not investment.nft_minted:
            # NFT minting handled by blockchain/tasks.py mint_nft_certificate
            from blockchain.tasks import mint_nft_certificate
            logger.info(f"Queuing NFT minting for investment {investment_id}")
            mint_nft_certificate.delay(str(investment.id))
        
        return {
            'success': True,
            'investment_id': investment_id,
            'tx_hash': result['txHash']
        }
        
    except Exception as e:
        logger.error(f"Failed to record investment {investment_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task
def sync_investment_from_blockchain(investment_id: str):
    """
    Sync investment data from blockchain
    Useful for verification and reconciliation
    """
    try:
        from .models import Investment
        from .services import InvestmentBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        investment = Investment.objects.select_related('campaign', 'user').get(id=investment_id)
        
        if not investment.campaign.smart_contract_address:
            logger.warning(f"Campaign not deployed, cannot sync investment {investment_id}")
            return
        
        client = get_blockchain_client()
        service = InvestmentBlockchainService(client)
        
        chain_amount = service.get_investor_contribution(
            campaign_address=investment.campaign.smart_contract_address,
            investor_address=investment.user.wallet_address
        )
        
        if chain_amount != investment.amount:
            logger.warning(
                f"Investment amount mismatch for {investment_id}: "
                f"DB={investment.amount}, Chain={chain_amount}"
            )
        
        return {
            'success': True,
            'investment_id': investment_id,
            'db_amount': str(investment.amount),
            'chain_amount': str(chain_amount)
        }
        
    except Exception as e:
        logger.error(f"Failed to sync investment {investment_id}: {e}")
        raise
