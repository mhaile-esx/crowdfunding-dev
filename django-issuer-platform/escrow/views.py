from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from .models import FundEscrow, RefundTransaction
from .serializers import FundEscrowSerializer, RefundTransactionSerializer
from .tasks import release_funds_to_issuer, process_refunds


class FundEscrowViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for fund escrow management (read-only)
    Fund release/refund triggered by campaign completion
    """
    permission_classes = [IsAuthenticated]
    serializer_class = FundEscrowSerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return FundEscrow.objects.none()

        user = self.request.user
        if not user.is_authenticated:
            return FundEscrow.objects.none()

        if getattr(user, 'role', None) == 'admin':
            return FundEscrow.objects.all()
        elif getattr(user, 'role', None) == 'issuer':
            return FundEscrow.objects.filter(campaign__company__user=user)
        else:
            return FundEscrow.objects.filter(
                campaign__investments__user=user
            ).distinct()

    @action(detail=True, methods=['post'], permission_classes=[IsAdminUser])
    def release_funds(self, request, pk=None):
        """
        Manually trigger fund release (admin only)
        """
        escrow = self.get_object()

        if escrow.status == 'released':
            return Response({
                'error': 'Funds already released'
            }, status=status.HTTP_400_BAD_REQUEST)

        if not escrow.campaign.is_successful:
            return Response({
                'error': 'Campaign did not meet success threshold'
            }, status=status.HTTP_400_BAD_REQUEST)

        release_funds_to_issuer.delay(str(escrow.campaign.id))

        return Response({
            'message': 'Fund release initiated'
        })

    @action(detail=True, methods=['post'], permission_classes=[IsAdminUser])
    def process_refunds(self, request, pk=None):
        """
        Manually trigger refund processing (admin only)
        """
        escrow = self.get_object()

        if escrow.status == 'refunded':
            return Response({
                'error': 'Refunds already processed'
            }, status=status.HTTP_400_BAD_REQUEST)

        if escrow.campaign.is_successful:
            return Response({
                'error': 'Cannot refund successful campaign'
            }, status=status.HTTP_400_BAD_REQUEST)

        process_refunds.delay(str(escrow.campaign.id))

        return Response({
            'message': 'Refund processing initiated'
        })


class RefundTransactionViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for refund transaction history (read-only)
    """
    permission_classes = [IsAuthenticated]
    serializer_class = RefundTransactionSerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return RefundTransaction.objects.none()

        user = self.request.user
        if not user.is_authenticated:
            return RefundTransaction.objects.none()

        if getattr(user, 'role', None) == 'admin':
            return RefundTransaction.objects.all()
        else:
            return RefundTransaction.objects.filter(investor=user)
