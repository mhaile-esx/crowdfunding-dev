from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum, Count
from .models import NFTShareCertificate, NFTTransferHistory
from .serializers import (
    NFTShareCertificateSerializer, NFTTransferHistorySerializer,
    NFTPortfolioSerializer
)


class NFTShareCertificateViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for NFT share certificate management (read-only)
    NFTs are automatically minted via Celery tasks
    """
    permission_classes = [IsAuthenticated]
    serializer_class = NFTShareCertificateSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        campaign_id = self.request.query_params.get('campaign', None)
        
        if user.role == 'admin':
            queryset = NFTShareCertificate.objects.all()
        else:
            # Users see their own NFTs
            queryset = NFTShareCertificate.objects.filter(investment__user=user)
        
        if campaign_id:
            queryset = queryset.filter(investment__campaign_id=campaign_id)
        
        return queryset.select_related('investment', 'investment__campaign')
    
    @action(detail=False, methods=['get'])
    def my_certificates(self, request):
        """
        Get current user's NFT certificates
        """
        certificates = NFTShareCertificate.objects.filter(
            investment__user=request.user
        ).select_related('investment', 'investment__campaign')
        
        serializer = NFTShareCertificateSerializer(certificates, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def portfolio(self, request):
        """
        Get NFT portfolio statistics for current user
        """
        user = request.user
        
        certificates = NFTShareCertificate.objects.filter(investment__user=user)
        
        # Calculate voting power (1 vote per 1000 ETB invested)
        total_investment = certificates.aggregate(
            Sum('investment__amount')
        )['investment__amount__sum'] or 0
        
        voting_power = int(total_investment / 1000)
        
        stats = {
            'total_nfts': certificates.count(),
            'total_campaigns': certificates.values('investment__campaign').distinct().count(),
            'total_investment_value': total_investment,
            'voting_power': voting_power
        }
        
        serializer = NFTPortfolioSerializer(stats)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def metadata(self, request, pk=None):
        """
        Get NFT metadata
        """
        certificate = self.get_object()
        
        metadata = {
            'token_id': certificate.token_id,
            'campaign': certificate.investment.campaign.title,
            'investor': certificate.investment.user.wallet_address,
            'amount': str(certificate.investment.amount),
            'share_percentage': float(
                certificate.investment.amount / certificate.investment.campaign.current_funding * 100
            ) if certificate.investment.campaign.current_funding > 0 else 0,
            'investment_date': certificate.investment.created_at.isoformat(),
            'mint_date': certificate.minted_at.isoformat(),
            'contract_address': certificate.contract_address,
            'metadata_uri': certificate.metadata_uri
        }
        
        return Response(metadata)


class NFTTransferHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for NFT transfer history (read-only)
    """
    permission_classes = [IsAuthenticated]
    serializer_class = NFTTransferHistorySerializer
    
    def get_queryset(self):
        user = self.request.user
        
        if user.role == 'admin':
            return NFTTransferHistory.objects.all()
        else:
            # Users see transfers involving their NFTs
            return NFTTransferHistory.objects.filter(
                nft__investment__user=user
            ).order_by('-transferred_at')
