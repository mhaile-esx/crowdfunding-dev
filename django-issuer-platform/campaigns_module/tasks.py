"""
Campaign Module Celery Tasks
Async blockchain operations for campaigns
"""
from celery import shared_task
from django.utils import timezone
from decimal import Decimal
import logging

logger = logging.getLogger('campaigns_module')


@shared_task(bind=True, max_retries=3)
def deploy_campaign_to_blockchain(self, campaign_id: str):
    """
    Deploy campaign to blockchain via CampaignFactory.sol
    
    Args:
        campaign_id: UUID of campaign to deploy
        
    Updates:
        - smart_contract_address
        - deployment_tx_hash
        - deployed_on_blockchain
        - blockchain_deployed_at
        - status (draft/pending → active)
    """
    try:
        from .models import Campaign
        from .services import CampaignBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        campaign = Campaign.objects.get(id=campaign_id)
        
        if campaign.deployed_on_blockchain:
            logger.info(f"Campaign {campaign_id} already deployed, skipping")
            return
        
        logger.info(f"Deploying campaign {campaign.title} to blockchain...")
        
        client = get_blockchain_client()
        service = CampaignBlockchainService(client)
        
        result = service.deploy_campaign(
            campaign_id=str(campaign.id),
            company_name=campaign.company.name,
            description=campaign.description,
            funding_goal=str(campaign.funding_goal),
            duration_days=campaign.duration,
            document_hash=campaign.ipfs_document_hash or ''
        )
        
        campaign.smart_contract_address = result['campaignAddress']
        campaign.deployment_tx_hash = result['txHash']
        campaign.deployed_on_blockchain = True
        campaign.blockchain_deployed_at = timezone.now()
        campaign.status = 'active'
        campaign.start_date = timezone.now()
        campaign.save()
        
        logger.info(
            f"Campaign deployed successfully: {campaign.title} "
            f"at {result['campaignAddress']}"
        )
        
        return {
            'success': True,
            'campaign_id': campaign_id,
            'contract_address': result['campaignAddress'],
            'tx_hash': result['txHash']
        }
        
    except Exception as e:
        logger.error(f"Failed to deploy campaign {campaign_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task
def sync_campaign_stats(campaign_id: str):
    """Alias for sync_campaign_stats_from_blockchain"""
    return sync_campaign_stats_from_blockchain(campaign_id)


@shared_task
def sync_campaign_stats_from_blockchain(campaign_id: str):
    """
    Sync campaign statistics from blockchain
    Useful for verification and reconciliation
    """
    try:
        from .models import Campaign
        from .services import CampaignBlockchainService
        from blockchain.web3_client import get_blockchain_client
        
        campaign = Campaign.objects.get(id=campaign_id)
        
        if not campaign.smart_contract_address:
            logger.warning(f"Campaign {campaign_id} not deployed, cannot sync")
            return
        
        client = get_blockchain_client()
        service = CampaignBlockchainService(client)
        
        chain_data = service.get_campaign_info(campaign.smart_contract_address)
        
        campaign.current_funding = Decimal(str(chain_data.get('currentFunding', 0)))
        
        investors = service.get_campaign_investors(campaign.smart_contract_address)
        campaign.investor_count = len(investors)
        
        campaign.save()
        
        logger.info(f"Campaign stats synced from blockchain: {campaign_id}")
        
        return {
            'success': True,
            'campaign_id': campaign_id,
            'current_funding': str(campaign.current_funding),
            'investor_count': campaign.investor_count
        }
        
    except Exception as e:
        logger.error(f"Failed to sync campaign stats {campaign_id}: {e}")
        raise
