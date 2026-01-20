from django.db import models
from django.utils import timezone
import uuid


class WalletNonce(models.Model):
    """
    Store wallet authentication nonces to prevent replay attacks
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet_address = models.CharField(max_length=42, db_index=True)
    nonce = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)
    used_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'wallet_nonces'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['wallet_address', 'nonce']),
            models.Index(fields=['expires_at']),
        ]
    
    def __str__(self):
        return f"{self.wallet_address[:10]}... - {self.nonce[:10]}..."
    
    @property
    def is_expired(self):
        """Check if nonce has expired"""
        return timezone.now() > self.expires_at
    
    @property
    def is_valid(self):
        """Check if nonce is valid (not used and not expired)"""
        return not self.used and not self.is_expired
    
    def mark_as_used(self):
        """Mark nonce as used"""
        self.used = True
        self.used_at = timezone.now()
        self.save()
