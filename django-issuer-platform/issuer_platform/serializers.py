from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Company, IssuerProfile, KYCDocument

User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm', 'wallet_address', 'role']
        extra_kwargs = {
            'wallet_address': {'required': False},
            'role': {'default': 'investor'}
        }

    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return data

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User.objects.create_user(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'wallet_address', 'kyc_verified',
                  'kyc_level', 'aml_risk_score', 'is_active', 'date_joined']
        read_only_fields = ['id', 'date_joined', 'kyc_verified', 'aml_risk_score']


class CompanySerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    sector_display = serializers.CharField(source='get_sector_display', read_only=True)

    class Meta:
        model = Company
        fields = [
            'id', 'user', 'name', 'tin_number', 'sector', 'sector_display',
            'registration_year', 'verified', 'logo_url', 'logo_ipfs_hash',
            'description', 'website', 'blockchain_address', 'ipfs_document_hash',
            'registered_on_blockchain', 'blockchain_tx_hash', 'blockchain_registered_at',
            'has_active_campaign', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'blockchain_address', 'verified',
                            'registered_on_blockchain', 'blockchain_tx_hash',
                            'blockchain_registered_at', 'created_at', 'updated_at']


class CompanyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = ['name', 'tin_number', 'sector', 'registration_year',
                  'logo_url', 'logo_ipfs_hash', 'description', 'website']


class IssuerProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    company = CompanySerializer(read_only=True)

    class Meta:
        model = IssuerProfile
        fields = [
            'id', 'user', 'company', 'phone_number', 'business_email', 'website',
            'street_address', 'city', 'state_province', 'postal_code', 'country',
            'business_description', 'years_in_operation', 'number_of_employees',
            'annual_revenue', 'compliance_officer_name', 'compliance_officer_email',
            'onboarding_completed', 'onboarding_step', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'company', 'created_at', 'updated_at']


class KYCDocumentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = KYCDocument
        fields = [
            'id', 'user', 'company', 'document_type', 'document_number', 'document_file',
            'ipfs_hash', 'ocr_processed', 'ocr_data', 'ai_verification_score',
            'status', 'verified_by', 'verified_at', 'rejection_reason',
            'issue_date', 'expiry_date', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'ipfs_hash', 'ocr_processed', 'ocr_data',
                            'ai_verification_score', 'status', 'verified_at',
                            'verified_by', 'created_at', 'updated_at']


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)


class WalletConnectSerializer(serializers.Serializer):
    wallet_address = serializers.CharField(max_length=42)
    signature = serializers.CharField()
    message = serializers.CharField()
