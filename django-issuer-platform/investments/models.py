"""
Django models for Investment Management
"""
from django.db import models
from django.core.validators import MinValueValidator
from issuers.models import User
from campaigns_module.models import Campaign
import uuid


class Investment(models.Model):
    """
    Investment records
    Dual storage: PostgreSQL + Blockchain (CampaignImplementation.sol)
    """
    PAYMENT_METHOD_CHOICES = [
        ('crypto', 'Cryptocurrency (MetaMask)'),
        ('telebirr', 'Telebirr'),
        ('cbe', 'Commercial Bank of Ethiopia'),
        ('awash', 'Awash Bank'),
        ('dashen', 'Dashen Bank'),
        ('abyssinia', 'Bank of Abyssinia'),
        ('other', 'Other'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='investments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='investments')
    
    # Investment details
    amount = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        validators=[MinValueValidator(100)]
    )
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES)
    
    # Transaction tracking
    transaction_hash = models.CharField(max_length=66, null=True, blank=True)
    payment_reference = models.CharField(max_length=100, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    # FIX: Blockchain tracking (dual-ledger)
    blockchain_tx_hash = models.CharField(
        max_length=66,
        null=True,
        blank=True,
        help_text="Blockchain transaction hash for on-chain recording"
    )
    blockchain_recorded_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when investment was recorded on blockchain"
    )
    
    # Yield/Returns
    yield_earned = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0,
        help_text="Yield earned from DeFi farming"
    )
    
    # NFT Certificate
    nft_token_id = models.CharField(max_length=100, null=True, blank=True)
    nft_minted = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    refunded_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'investments'
        verbose_name = 'Investment'
        verbose_name_plural = 'Investments'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.user.username} → {self.campaign.title}: {self.amount} ETB"
    
    @property
    def voting_power(self):
        """Calculate voting power: 1 vote per 1000 ETB invested"""
        return int(float(self.amount) / 1000)


class NFTShareCertificate(models.Model):
    """
    NFT Share Certificate records
    Links to blockchain NFT contract
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    investment = models.OneToOneField(
        Investment,
        on_delete=models.CASCADE,
        related_name='nft_certificate'
    )
    
    # NFT details
    token_id = models.CharField(max_length=100, unique=True)
    contract_address = models.CharField(max_length=42)
    token_uri = models.URLField(max_length=500, null=True, blank=True)
    
    # Metadata
    metadata = models.JSONField(null=True, blank=True)
    voting_weight = models.DecimalField(max_digits=10, decimal_places=6, default=0)
    
    # Minting details
    mint_tx_hash = models.CharField(max_length=66)
    minted_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'nft_share_certificates'
        verbose_name = 'NFT Share Certificate'
        verbose_name_plural = 'NFT Share Certificates'
        ordering = ['-minted_at']
    
    def __str__(self):
        return f"NFT #{self.token_id} - {self.investment.user.username}"


class Payment(models.Model):
    """
    Ethiopian payment gateway transactions
    """
    PROVIDER_CHOICES = [
        ('telebirr', 'Telebirr'),
        ('cbe', 'CBE'),
        ('awash', 'Awash Bank'),
        ('dashen', 'Dashen Bank'),
        ('abyssinia', 'Bank of Abyssinia'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    investment = models.ForeignKey(
        Investment,
        on_delete=models.CASCADE,
        related_name='payments',
        null=True,
        blank=True
    )
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='payments')
    
    # Payment details
    transaction_id = models.CharField(max_length=100, unique=True)
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES)
    
    # Payment method specific
    phone_number = models.CharField(max_length=20, blank=True)
    account_number = models.CharField(max_length=50, blank=True)
    
    # Status tracking
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    description = models.TextField(blank=True)
    error_message = models.TextField(blank=True)
    
    # Provider response
    provider_reference = models.CharField(max_length=100, blank=True)
    provider_response = models.JSONField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'payments'
        verbose_name = 'Payment'
        verbose_name_plural = 'Payments'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.provider} - {self.transaction_id}: {self.amount} ETB"
