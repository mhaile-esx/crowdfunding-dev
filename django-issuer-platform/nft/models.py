"""
NFT Module Models
NFT Share Certificates with blockchain integration
"""
from django.db import models
from issuers.models import User
from campaigns_module.models import Campaign
import uuid


class NFTShareCertificate(models.Model):
    """
    NFT Share Certificate
    Represents blockchain-based ownership certificates
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='nft_certificates')
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='nft_certificates')
    
    token_id = models.CharField(max_length=100, unique=True)
    contract_address = models.CharField(max_length=42)
    
    investment_amount = models.DecimalField(max_digits=15, decimal_places=2)
    
    voting_weight = models.DecimalField(
        max_digits=10,
        decimal_places=6,
        default=0,
        help_text="Voting power (1 vote per 1000 ETB)"
    )
    
    token_uri = models.URLField(max_length=500, null=True, blank=True)
    metadata = models.JSONField(
        null=True,
        blank=True,
        help_text="NFT metadata (name, description, image, attributes)"
    )
    
    mint_tx_hash = models.CharField(max_length=66)
    minted_at = models.DateTimeField(auto_now_add=True)
    
    transferred = models.BooleanField(default=False)
    transfer_count = models.IntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'nft_share_certificates'
        verbose_name = 'NFT Share Certificate'
        verbose_name_plural = 'NFT Share Certificates'
        ordering = ['-minted_at']
        indexes = [
            models.Index(fields=['owner']),
            models.Index(fields=['campaign']),
            models.Index(fields=['token_id']),
        ]
    
    def __str__(self):
        return f"NFT #{self.token_id} - {self.owner.username} - {self.campaign.title}"
    
    @property
    def voting_power(self):
        """Calculate voting power: 1 vote per 1000 ETB invested"""
        return int(float(self.investment_amount) / 1000)


class NFTTransferHistory(models.Model):
    """
    NFT transfer history tracking
    Records all ownership changes
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nft = models.ForeignKey(
        NFTShareCertificate,
        on_delete=models.CASCADE,
        related_name='transfer_history'
    )
    
    from_address = models.CharField(max_length=42)
    to_address = models.CharField(max_length=42)
    
    transfer_tx_hash = models.CharField(max_length=66)
    transferred_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'nft_transfer_history'
        verbose_name = 'NFT Transfer History'
        verbose_name_plural = 'NFT Transfer History'
        ordering = ['-transferred_at']
    
    def __str__(self):
        return f"NFT #{self.nft.token_id} transfer: {self.from_address[:10]}... → {self.to_address[:10]}..."
