"""
Campaign Module Models
Dual storage: PostgreSQL + Blockchain (CampaignFactory.sol)
"""
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from issuers.models import Company, User
import uuid


class Campaign(models.Model):
    """
    Campaign model for fundraising campaigns
    Blockchain integration via CampaignFactory.sol and CampaignImplementation.sol
    """
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('pending', 'Pending Approval'),
        ('approved', 'Approved'),
        ('active', 'Active'),
        ('successful', 'Successful'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='campaigns')

    title = models.CharField(max_length=255)
    description = models.TextField()
    funding_goal = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        validators=[MinValueValidator(1000)],
        help_text="Funding goal in ETB"
    )
    current_funding = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0
    )
    min_investment = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=100,
        help_text="Minimum investment amount"
    )
    max_investment = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Maximum investment amount (optional)"
    )
    duration = models.IntegerField(
        validators=[MinValueValidator(30), MaxValueValidator(180)],
        help_text="Campaign duration in days"
    )
    success_threshold = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=75,
        help_text="Success threshold percentage (default 75%)"
    )

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    start_date = models.DateTimeField(null=True, blank=True)
    end_date = models.DateTimeField(null=True, blank=True)

    smart_contract_address = models.CharField(max_length=42, null=True, blank=True)
    deployment_tx_hash = models.CharField(max_length=66, null=True, blank=True)
    deployed_on_blockchain = models.BooleanField(default=False)
    blockchain_deployed_at = models.DateTimeField(null=True, blank=True)
    ipfs_document_hash = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        help_text="IPFS hash for campaign documents"
    )

    approved = models.BooleanField(default=False)
    approved_at = models.DateTimeField(null=True, blank=True)
    approved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_campaigns'
    )

    funds_released = models.BooleanField(default=False)
    funds_released_at = models.DateTimeField(null=True, blank=True)
    funds_release_tx_hash = models.CharField(max_length=66, null=True, blank=True)

    investor_count = models.IntegerField(default=0)
    total_shares_issued = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'campaigns'
        verbose_name = 'Campaign'
        verbose_name_plural = 'Campaigns'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['company']),
            models.Index(fields=['smart_contract_address']),
        ]

    def __str__(self):
        return f"{self.title} ({self.company.name})"

    @property
    def progress_percentage(self):
        if self.funding_goal > 0:
            return (float(self.current_funding) / float(self.funding_goal)) * 100
        return 0

    @property
    def is_successful(self):
        return self.progress_percentage >= float(self.success_threshold)

    def can_deploy_to_blockchain(self):
        return (
            self.status == 'approved' and
            not self.deployed_on_blockchain and
            self.company.registered_on_blockchain
        )


class CampaignDocument(models.Model):
    """Campaign supporting documents"""
    DOCUMENT_TYPES = [
        ('business_plan', 'Business Plan'),
        ('financial_statement', 'Financial Statement'),
        ('legal_document', 'Legal Document'),
        ('other', 'Other'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='documents')

    title = models.CharField(max_length=255)
    document_type = models.CharField(max_length=30, choices=DOCUMENT_TYPES)
    file_url = models.URLField(max_length=500)
    ipfs_hash = models.CharField(max_length=100, null=True, blank=True)

    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'campaign_documents'
        verbose_name = 'Campaign Document'
        verbose_name_plural = 'Campaign Documents'
        ordering = ['-uploaded_at']

    def __str__(self):
        return f"{self.title} ({self.campaign.title})"


class CampaignUpdate(models.Model):
    """Campaign progress updates"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='updates')

    title = models.CharField(max_length=255)
    content = models.TextField()
    posted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'campaign_updates'
        verbose_name = 'Campaign Update'
        verbose_name_plural = 'Campaign Updates'
        ordering = ['-posted_at']

    def __str__(self):
        return f"{self.title} - {self.campaign.title}"
