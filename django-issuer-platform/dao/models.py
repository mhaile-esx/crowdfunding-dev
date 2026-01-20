import uuid
from django.db import models
from django.utils import timezone
from issuers.models import User
from campaigns_module.models import Campaign

class DAOProposal(models.Model):
    PROPOSAL_TYPE_CHOICES = [
        ('campaign', 'Campaign Decision'),
        ('platform', 'Platform Upgrade'),
        ('treasury', 'Treasury Allocation'),
        ('governance', 'Governance Change'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('active', 'Active'),
        ('passed', 'Passed'),
        ('failed', 'Failed'),
        ('executed', 'Executed'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blockchain_id = models.CharField(max_length=66, null=True, blank=True, db_index=True)
    title = models.CharField(max_length=255)
    description = models.TextField()
    proposal_type = models.CharField(max_length=20, choices=PROPOSAL_TYPE_CHOICES, default='platform')
    proposer = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='dao_proposals')
    proposer_address = models.CharField(max_length=42)
    campaign = models.ForeignKey(Campaign, on_delete=models.SET_NULL, null=True, blank=True, related_name='dao_proposals')
    target_address = models.CharField(max_length=42, null=True, blank=True)
    amount = models.DecimalField(max_digits=20, decimal_places=2, default=0)
    voting_duration = models.IntegerField(default=86400)
    start_time = models.DateTimeField(default=timezone.now)
    end_time = models.DateTimeField()
    votes_for = models.DecimalField(max_digits=20, decimal_places=0, default=0)
    votes_against = models.DecimalField(max_digits=20, decimal_places=0, default=0)
    quorum = models.DecimalField(max_digits=20, decimal_places=0, default=1000)
    voting_power_required = models.DecimalField(max_digits=20, decimal_places=0, default=100)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    executed = models.BooleanField(default=False)
    executed_at = models.DateTimeField(null=True, blank=True)
    transaction_hash = models.CharField(max_length=66, null=True, blank=True)
    execution_hash = models.CharField(max_length=66, null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    synced_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def save(self, *args, **kwargs):
        if not self.end_time:
            self.end_time = self.start_time + timezone.timedelta(seconds=self.voting_duration)
        super().save(*args, **kwargs)
    
    @property
    def total_votes(self):
        return self.votes_for + self.votes_against
    
    @property
    def is_active(self):
        now = timezone.now()
        return self.start_time <= now <= self.end_time and self.status == 'active'

class DAOVote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    proposal = models.ForeignKey(DAOProposal, on_delete=models.CASCADE, related_name='votes')
    voter = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='dao_votes')
    voter_address = models.CharField(max_length=42, db_index=True)
    support = models.BooleanField()
    voting_power = models.DecimalField(max_digits=20, decimal_places=0)
    transaction_hash = models.CharField(max_length=66, null=True, blank=True)
    cast_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)
    synced_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ['-cast_at']
        unique_together = ['proposal', 'voter_address']
