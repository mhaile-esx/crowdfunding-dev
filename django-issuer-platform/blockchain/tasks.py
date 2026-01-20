"""
Celery tasks for async blockchain operations
FIX: Implements dual-ledger synchronization
"""
from celery import shared_task
from django.db import transaction
from django.utils import timezone
import logging

logger = logging.getLogger('blockchain')


@shared_task(bind=True, max_retries=3)
def register_issuer_on_blockchain(self, company_id):
    """
    Register issuer on blockchain (async)
    FIX: Properly syncs blockchain result back to PostgreSQL
    
    Args:
        company_id: UUID of company to register
    """
    from issuers.models import Company
    from blockchain.services import IssuerBlockchainService
    
    try:
        company = Company.objects.get(id=company_id)
        
        if not company.user.wallet_address:
            raise ValueError(f"Company {company_id} has no wallet address")
        
        logger.info(f"Registering issuer {company.name} on blockchain...")
        
        service = IssuerBlockchainService()
        result = service.register_issuer(
            issuer_address=company.user.wallet_address,
            vc_hash=company.user.vc_hash or '',
            ipfs_hash=company.ipfs_document_hash or ''
        )
        
        # FIX: Update company with blockchain data
        with transaction.atomic():
            company.blockchain_address = company.user.wallet_address
            company.registered_on_blockchain = True
            company.blockchain_tx_hash = result['txHash']
            company.blockchain_registered_at = timezone.now()
            company.save(update_fields=[
                'blockchain_address',
                'registered_on_blockchain',
                'blockchain_tx_hash',
                'blockchain_registered_at'
            ])
        
        logger.info(f"Issuer {company.name} registered on blockchain: {result['txHash']}")
        return result
        
    except Company.DoesNotExist:
        logger.error(f"Company {company_id} not found")
        raise
    except Exception as e:
        logger.error(f"Failed to register issuer {company_id}: {e}")
        # Retry on failure
        raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def deploy_campaign_to_blockchain(self, campaign_id):
    """
    Deploy campaign to blockchain (async)
    FIX: Parses events and saves contract address to DB
    
    Args:
        campaign_id: UUID of campaign to deploy
    """
    from campaigns_module.models import Campaign
    from blockchain.services import CampaignBlockchainService
    
    try:
        campaign = Campaign.objects.get(id=campaign_id)
        
        if campaign.deployed_on_blockchain:
            logger.warning(f"Campaign {campaign_id} already deployed")
            return {'success': False, 'message': 'Already deployed'}
        
        logger.info(f"Deploying campaign {campaign.title} to blockchain...")
        
        service = CampaignBlockchainService()
        result = service.create_campaign(
            campaign_id=str(campaign.id),
            company_name=campaign.company.name,
            description=campaign.description[:500],
            funding_goal=str(campaign.funding_goal),
            duration_days=campaign.duration,
            document_hash=campaign.ipfs_document_hash or ''
        )
        
        # FIX: Update campaign with blockchain data
        with transaction.atomic():
            campaign.smart_contract_address = result['campaignAddress']
            campaign.deployment_tx_hash = result['txHash']
            campaign.deployed_on_blockchain = True
            campaign.blockchain_deployed_at = timezone.now()
            campaign.status = 'active'
            campaign.save(update_fields=[
                'smart_contract_address',
                'deployment_tx_hash',
                'deployed_on_blockchain',
                'blockchain_deployed_at',
                'status'
            ])
        
        logger.info(f"Campaign {campaign.title} deployed: {result['campaignAddress']}")
        return result
        
    except Campaign.DoesNotExist:
        logger.error(f"Campaign {campaign_id} not found")
        raise
    except Exception as e:
        logger.error(f"Failed to deploy campaign {campaign_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def record_investment_on_blockchain(self, investment_id):
    """
    Record investment on blockchain (async)
    FIX: Updates investment record with blockchain tx
    
    Args:
        investment_id: UUID of investment to record
    """
    from investments.models import Investment
    from blockchain.services import CampaignBlockchainService
    
    try:
        investment = Investment.objects.get(id=investment_id)
        
        if investment.blockchain_tx_hash:
            logger.warning(f"Investment {investment_id} already recorded on blockchain")
            return {'success': False, 'message': 'Already recorded'}
        
        logger.info(f"Recording investment {investment_id} on blockchain...")
        
        service = CampaignBlockchainService()
        result = service.record_investment(
            campaign_address=investment.campaign.smart_contract_address,
            investor_address=investment.user.wallet_address,
            amount=investment.amount,
            payment_method=investment.payment_method,
            transaction_reference=str(investment.id)
        )
        
        # FIX: Update investment with blockchain data
        with transaction.atomic():
            investment.blockchain_tx_hash = result['txHash']
            investment.blockchain_recorded_at = timezone.now()
            investment.save(update_fields=[
                'blockchain_tx_hash',
                'blockchain_recorded_at'
            ])
        
        logger.info(f"Investment {investment_id} recorded on blockchain: {result['txHash']}")
        return result
        
    except Investment.DoesNotExist:
        logger.error(f"Investment {investment_id} not found")
        raise
    except Exception as e:
        logger.error(f"Failed to record investment {investment_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def mint_nft_certificate(self, investment_id):
    """
    Mint NFT certificate for successful investment (async)
    FIX: Creates NFTShareCertificate record in DB
    
    Args:
        investment_id: UUID of investment
    """
    from investments.models import Investment, NFTShareCertificate
    from blockchain.services import NFTCertificateService
    
    try:
        investment = Investment.objects.get(id=investment_id)
        
        if hasattr(investment, 'nft_certificate'):
            logger.warning(f"NFT already minted for investment {investment_id}")
            return {'success': False, 'message': 'Already minted'}
        
        logger.info(f"Minting NFT certificate for investment {investment_id}...")
        
        # Calculate shares (1 share per 1000 ETB)
        shares = int(investment.amount / 1000)
        
        service = NFTCertificateService()
        result = service.mint_certificate(
            investor_address=investment.user.wallet_address,
            campaign_id=str(investment.campaign.id),
            company_name=investment.campaign.company.name,
            investment_amount=investment.amount,
            share_count=shares,
            token_uri=f"ipfs://certificates/{investment.id}"
        )
        
        # FIX: Create NFTShareCertificate record
        with transaction.atomic():
            nft = NFTShareCertificate.objects.create(
                investment=investment,
                token_id=result['tokenId'],
                owner_address=investment.user.wallet_address,
                campaign=investment.campaign,
                company=investment.campaign.company,
                shares=shares,
                minting_tx_hash=result['txHash'],
                minted_at=timezone.now()
            )
        
        logger.info(f"NFT certificate minted: Token ID {result['tokenId']}")
        return result
        
    except Investment.DoesNotExist:
        logger.error(f"Investment {investment_id} not found")
        raise
    except Exception as e:
        logger.error(f"Failed to mint NFT for investment {investment_id}: {e}")
        raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def release_campaign_funds(self, campaign_id):
    """
    Release funds for successful campaign (async)
    FIX: Updates campaign status in DB
    
    Args:
        campaign_id: UUID of campaign
    """
    from campaigns_module.models import Campaign
    from blockchain.services import CampaignBlockchainService
    
    try:
        campaign = Campaign.objects.get(id=campaign_id)
        
        if campaign.status == 'successful':
            logger.warning(f"Funds already released for campaign {campaign_id}")
            return {'success': False, 'message': 'Already released'}
        
        logger.info(f"Releasing funds for campaign {campaign.title}...")
        
        service = CampaignBlockchainService()
        result = service.release_funds(campaign.smart_contract_address)
        
        # FIX: Update campaign status
        with transaction.atomic():
            campaign.status = 'successful'
            campaign.funds_released_at = timezone.now()
            campaign.funds_release_tx_hash = result['txHash']
            campaign.save(update_fields=[
                'status',
                'funds_released_at',
                'funds_release_tx_hash'
            ])
        
        logger.info(f"Funds released for campaign {campaign.title}: {result['txHash']}")
        return result
        
    except Campaign.DoesNotExist:
        logger.error(f"Campaign {campaign_id} not found")
        raise
    except Exception as e:
        logger.error(f"Failed to release funds for campaign {campaign_id}: {e}")
        raise self.retry(exc=e, countdown=60)
