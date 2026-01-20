from rest_framework import serializers
from .models import NFTShareCertificate, NFTTransferHistory
from issuers.serializers import UserSerializer


class NFTShareCertificateSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)

    class Meta:
        model = NFTShareCertificate
        fields = [
            'id', 'owner', 'campaign', 'token_id', 'contract_address',
            'investment_amount', 'voting_weight', 'token_uri', 'metadata',
            'mint_tx_hash', 'minted_at', 'transferred', 'transfer_count',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'owner', 'campaign', 'token_id', 'contract_address',
            'investment_amount', 'voting_weight', 'token_uri', 'metadata',
            'mint_tx_hash', 'minted_at', 'transferred', 'transfer_count',
            'created_at', 'updated_at'
        ]


class NFTTransferHistorySerializer(serializers.ModelSerializer):
    nft = NFTShareCertificateSerializer(read_only=True)

    class Meta:
        model = NFTTransferHistory
        fields = [
            'id', 'nft', 'from_address', 'to_address',
            'transfer_tx_hash', 'transferred_at'
        ]
        read_only_fields = [
            'id', 'nft', 'from_address', 'to_address',
            'transfer_tx_hash', 'transferred_at'
        ]


class NFTPortfolioSerializer(serializers.Serializer):
    total_nfts = serializers.IntegerField()
    total_campaigns = serializers.IntegerField()
    total_investment_value = serializers.DecimalField(max_digits=15, decimal_places=2)
    voting_power = serializers.IntegerField()
