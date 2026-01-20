from rest_framework import serializers
from .models import Investment, NFTShareCertificate, Payment
from issuers.serializers import UserSerializer


class InvestmentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = Investment
        fields = [
            'id', 'campaign', 'user', 'amount', 'payment_method', 'status',
            'transaction_hash', 'payment_reference', 'blockchain_tx_hash', 
            'blockchain_recorded_at', 'yield_earned', 'nft_minted', 'nft_token_id', 
            'created_at', 'confirmed_at', 'refunded_at'
        ]
        read_only_fields = [
            'id', 'user', 'status', 'transaction_hash', 'blockchain_tx_hash', 
            'blockchain_recorded_at', 'yield_earned', 'nft_minted', 'nft_token_id', 
            'created_at', 'confirmed_at', 'refunded_at'
        ]


class InvestmentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Investment
        fields = ['campaign', 'amount', 'payment_method', 'payment_reference']

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Investment amount must be greater than 0")
        return value


class NFTShareCertificateSerializer(serializers.ModelSerializer):
    class Meta:
        model = NFTShareCertificate
        fields = [
            'id', 'investment', 'token_id', 'contract_address', 'token_uri',
            'metadata', 'voting_weight', 'mint_tx_hash', 'minted_at'
        ]
        read_only_fields = [
            'id', 'investment', 'token_id', 'contract_address', 'token_uri',
            'metadata', 'voting_weight', 'mint_tx_hash', 'minted_at'
        ]


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            'id', 'investment', 'campaign', 'transaction_id', 'amount', 'provider',
            'phone_number', 'account_number', 'status', 'description', 'error_message',
            'provider_reference', 'provider_response', 'created_at', 'updated_at', 'completed_at'
        ]
        read_only_fields = [
            'id', 'transaction_id', 'status', 'provider_reference', 'provider_response',
            'created_at', 'updated_at', 'completed_at'
        ]


class InvestmentStatsSerializer(serializers.Serializer):
    total_invested = serializers.DecimalField(max_digits=15, decimal_places=2)
    total_investments = serializers.IntegerField()
    campaigns_invested = serializers.IntegerField()
    nfts_owned = serializers.IntegerField()
    average_investment = serializers.DecimalField(max_digits=15, decimal_places=2)
