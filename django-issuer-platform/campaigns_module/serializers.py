from rest_framework import serializers
from .models import Campaign, CampaignDocument, CampaignUpdate
from issuers.serializers import CompanySerializer


class CampaignDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = CampaignDocument
        fields = [
            'id', 'campaign', 'title', 'document_type', 'file_url',
            'ipfs_hash', 'uploaded_at'
        ]
        read_only_fields = ['id', 'ipfs_hash', 'uploaded_at']


class CampaignUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = CampaignUpdate
        fields = [
            'id', 'campaign', 'title', 'content', 'posted_at'
        ]
        read_only_fields = ['id', 'posted_at']


class CampaignSerializer(serializers.ModelSerializer):
    company = CompanySerializer(read_only=True)
    documents = CampaignDocumentSerializer(many=True, read_only=True)
    updates = CampaignUpdateSerializer(many=True, read_only=True)

    progress_percentage = serializers.SerializerMethodField()
    days_remaining = serializers.SerializerMethodField()

    class Meta:
        model = Campaign
        fields = [
            'id', 'company', 'title', 'description', 'funding_goal',
            'current_funding', 'investor_count', 'duration',
            'status', 'start_date', 'end_date', 'approved', 'approved_by', 'approved_at',
            'smart_contract_address', 'deployment_tx_hash', 'deployed_on_blockchain',
            'blockchain_deployed_at', 'ipfs_document_hash',
            'funds_released', 'funds_released_at', 'funds_release_tx_hash',
            'success_threshold', 'total_shares_issued', 'created_at', 'updated_at',
            'documents', 'updates', 'progress_percentage', 'days_remaining'
        ]
        read_only_fields = [
            'id', 'company', 'current_funding', 'investor_count', 'status',
            'approved', 'approved_by', 'approved_at', 'smart_contract_address',
            'deployment_tx_hash', 'deployed_on_blockchain', 'blockchain_deployed_at',
            'funds_released', 'funds_released_at', 'funds_release_tx_hash',
            'total_shares_issued', 'created_at', 'updated_at'
        ]

    def get_progress_percentage(self, obj):
        if obj.funding_goal > 0:
            return round((float(obj.current_funding) / float(obj.funding_goal)) * 100, 2)
        return 0

    def get_days_remaining(self, obj):
        from django.utils import timezone
        if obj.end_date:
            delta = obj.end_date - timezone.now()
            return max(0, delta.days)
        return 0


class CampaignCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Campaign
        fields = [
            'title', 'description', 'funding_goal',
            'duration', 'success_threshold'
        ]


class CampaignStatsSerializer(serializers.Serializer):
    total_funding = serializers.DecimalField(max_digits=15, decimal_places=2)
    investor_count = serializers.IntegerField()
    average_investment = serializers.DecimalField(max_digits=15, decimal_places=2)
    progress_percentage = serializers.FloatField()
    days_remaining = serializers.IntegerField()
    is_successful = serializers.BooleanField()
    blockchain_synced = serializers.BooleanField()
    last_synced = serializers.DateTimeField()
