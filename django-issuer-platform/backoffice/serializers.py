"""
Serializers for backoffice administration
"""
from rest_framework import serializers
from issuers.models import Company, User, KYCDocument, IssuerProfile
from campaigns_module.models import Campaign, CampaignDocument


class AdminUserSerializer(serializers.ModelSerializer):
    """User serializer with admin-level details"""
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'wallet_address', 'kyc_level', 'kyc_verified',
            'kyc_verified_at', 'aml_risk_score', 'is_active', 'is_staff',
            'date_joined', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'date_joined', 'created_at', 'updated_at']


class AdminCompanySerializer(serializers.ModelSerializer):
    """Company serializer with all details for admin review"""
    owner = AdminUserSerializer(source='user', read_only=True)
    pending_documents_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Company
        fields = [
            'id', 'name', 'tin_number', 'sector', 'registration_year',
            'verified', 'logo_url', 'description', 'website',
            'blockchain_address', 'registered_on_blockchain',
            'has_active_campaign', 'owner', 'pending_documents_count',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_pending_documents_count(self, obj):
        return obj.kyc_documents.filter(status='pending').count()


class AdminKYCDocumentSerializer(serializers.ModelSerializer):
    """KYC document serializer for admin review"""
    user_info = AdminUserSerializer(source='user', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True, allow_null=True)
    
    class Meta:
        model = KYCDocument
        fields = [
            'id', 'user', 'user_info', 'company', 'company_name',
            'document_type', 'document_number', 'document_file',
            'ipfs_hash', 'ocr_processed', 'ocr_data', 'ai_verification_score',
            'status', 'verified_by', 'verified_at', 'rejection_reason',
            'issue_date', 'expiry_date', 'is_expired',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at', 'is_expired']


class KYCReviewSerializer(serializers.Serializer):
    """Serializer for KYC document review action"""
    action = serializers.ChoiceField(choices=['approve', 'reject'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)
    kyc_level = serializers.ChoiceField(
        choices=['basic', 'enhanced', 'premium'],
        required=False,
        help_text="KYC level to assign if approving"
    )


class AdminCampaignSerializer(serializers.ModelSerializer):
    """Campaign serializer with all details for admin review"""
    company_info = AdminCompanySerializer(source='company', read_only=True)
    progress_percentage = serializers.FloatField(read_only=True)
    documents = serializers.SerializerMethodField()
    
    class Meta:
        model = Campaign
        fields = [
            'id', 'company', 'company_info', 'title', 'description',
            'funding_goal', 'current_funding', 'duration', 'success_threshold',
            'status', 'start_date', 'end_date', 'progress_percentage',
            'smart_contract_address', 'deployed_on_blockchain',
            'approved', 'approved_at', 'approved_by',
            'investor_count', 'total_shares_issued', 'documents',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'progress_percentage']
    
    def get_documents(self, obj):
        return CampaignDocumentSerializer(obj.documents.all(), many=True).data


class CampaignDocumentSerializer(serializers.ModelSerializer):
    """Campaign document serializer"""
    class Meta:
        model = CampaignDocument
        fields = [
            'id', 'document_type', 'title', 'file', 'ipfs_hash',
            'file_size', 'uploaded_at'
        ]


class CampaignReviewSerializer(serializers.Serializer):
    """Serializer for campaign review action"""
    action = serializers.ChoiceField(choices=['approve', 'reject', 'request_changes'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)
    review_notes = serializers.CharField(required=False, allow_blank=True)


class CompanyReviewSerializer(serializers.Serializer):
    """Serializer for company/issuer review action"""
    action = serializers.ChoiceField(choices=['verify', 'reject', 'request_documents'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)
    required_documents = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        help_text="List of additional documents required"
    )


class DashboardStatsSerializer(serializers.Serializer):
    """Serializer for admin dashboard statistics"""
    pending_issuers = serializers.IntegerField()
    pending_kyc_documents = serializers.IntegerField()
    pending_campaigns = serializers.IntegerField()
    active_campaigns = serializers.IntegerField()
    total_issuers = serializers.IntegerField()
    total_investors = serializers.IntegerField()
    total_funding_raised = serializers.DecimalField(max_digits=20, decimal_places=2)
    recent_activities = serializers.ListField(child=serializers.DictField())
