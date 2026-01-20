from rest_framework import serializers
from .models import FundEscrow, RefundTransaction
from issuers.serializers import UserSerializer


class RefundTransactionSerializer(serializers.ModelSerializer):
    investor = UserSerializer(read_only=True)

    class Meta:
        model = RefundTransaction
        fields = [
            'id', 'escrow', 'investor', 'amount', 'tx_hash', 'refunded_at'
        ]
        read_only_fields = ['id', 'escrow', 'investor', 'amount', 'tx_hash', 'refunded_at']


class FundEscrowSerializer(serializers.ModelSerializer):
    refund_transactions = RefundTransactionSerializer(many=True, read_only=True)

    class Meta:
        model = FundEscrow
        fields = [
            'id', 'campaign', 'total_escrowed', 'status', 'escrow_contract_address',
            'funds_released', 'funds_released_at', 'release_tx_hash', 'released_to_address',
            'refund_initiated', 'refund_completed', 'refund_tx_hash', 'refunded_at',
            'refund_transactions', 'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'campaign', 'total_escrowed', 'status', 'escrow_contract_address',
            'funds_released', 'funds_released_at', 'release_tx_hash', 'released_to_address',
            'refund_initiated', 'refund_completed', 'refund_tx_hash', 'refunded_at',
            'created_at', 'updated_at'
        ]
