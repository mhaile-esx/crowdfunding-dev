"""
Escrow Module Models
Manages fund escrow, release, and refund operations
"""
from django.db import models
from campaigns_module.models import Campaign
from issuers.models import User
import uuid


class FundEscrow(models.Model):
    """
    Fund escrow records
    Tracks escrowed funds for campaigns on blockchain
    """
    STATUS_CHOICES = [
        ('escrowed', 'Escrowed'),
        ('released', 'Released'),
        ('refunded', 'Refunded'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    campaign = models.OneToOneField(
        Campaign,
        on_delete=models.CASCADE,
        related_name='escrow'
    )
    
    total_escrowed = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0,
        help_text="Total amount held in escrow"
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='escrowed')
    
    escrow_contract_address = models.CharField(max_length=42, null=True, blank=True)
    
    funds_released = models.BooleanField(default=False)
    funds_released_at = models.DateTimeField(null=True, blank=True)
    release_tx_hash = models.CharField(max_length=66, null=True, blank=True)
    released_to_address = models.CharField(max_length=42, null=True, blank=True)
    
    refund_initiated = models.BooleanField(default=False)
    refund_completed = models.BooleanField(default=False)
    refund_tx_hash = models.CharField(max_length=66, null=True, blank=True)
    refunded_at = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'fund_escrows'
        verbose_name = 'Fund Escrow'
        verbose_name_plural = 'Fund Escrows'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['campaign']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"Escrow for {self.campaign.title}: {self.total_escrowed} ETB"
    
    @property
    def can_release_funds(self):
        """Check if funds can be released to campaign issuer"""
        return (
            self.status == 'escrowed' and
            not self.funds_released and
            self.campaign.is_successful and
            self.campaign.status == 'active'
        )
    
    @property
    def can_refund(self):
        """Check if funds should be refunded to investors"""
        return (
            self.status == 'escrowed' and
            not self.funds_released and
            self.campaign.status in ['failed', 'cancelled']
        )


class RefundTransaction(models.Model):
    """
    Individual refund transaction records
    Tracks refunds to each investor
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    escrow = models.ForeignKey(FundEscrow, on_delete=models.CASCADE, related_name='refund_transactions')
    investor = models.ForeignKey(User, on_delete=models.CASCADE)
    
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    tx_hash = models.CharField(max_length=66)
    refunded_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'refund_transactions'
        verbose_name = 'Refund Transaction'
        verbose_name_plural = 'Refund Transactions'
        ordering = ['-refunded_at']
    
    def __str__(self):
        return f"Refund to {self.investor.username}: {self.amount} ETB"
