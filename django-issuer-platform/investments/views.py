from rest_framework import viewsets, status, permissions, serializers as drf_serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.db.models import Sum, Count, Avg
from .models import Investment
from .serializers import (
    InvestmentSerializer, InvestmentCreateSerializer, InvestmentStatsSerializer
)
from campaigns_module.models import Campaign


class InvestmentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for investment management
    """
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return InvestmentCreateSerializer
        return InvestmentSerializer
    
    def get_queryset(self):
        # Handle swagger schema generation
        if getattr(self, 'swagger_fake_view', False):
            return Investment.objects.none()
        
        user = self.request.user
        
        # Handle anonymous users
        if not user.is_authenticated:
            return Investment.objects.none()
        
        # Filter by campaign if provided
        campaign_id = self.request.query_params.get('campaign', None)
        
        if getattr(user, 'role', None) == 'admin':
            queryset = Investment.objects.all()
        elif getattr(user, 'role', None) == 'issuer':
            queryset = Investment.objects.filter(campaign__company__owner=user)
        else:
            queryset = Investment.objects.filter(user=user)
        
        if campaign_id:
            queryset = queryset.filter(campaign_id=campaign_id)
        
        return queryset.select_related('user', 'campaign').order_by('-created_at')
    
    @transaction.atomic
    def create(self, request, *args, **kwargs):
        """
        Create investment and return full investment data with ID
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        campaign = serializer.validated_data['campaign']
        amount = serializer.validated_data['amount']
        
        # Validate campaign is active
        if campaign.status != 'active':
            raise drf_serializers.ValidationError({
                'campaign': 'Campaign is not active'
            })
        
        # Validate campaign has smart contract
        if not campaign.smart_contract_address:
            raise drf_serializers.ValidationError({
                'campaign': 'Campaign not deployed to blockchain'
            })
        
        # Validate amount limits
        min_investment = getattr(campaign, 'min_investment', 100)
        max_investment = getattr(campaign, 'max_investment', None)
        
        if amount < min_investment:
            raise drf_serializers.ValidationError({
                'amount': f'Minimum investment is {min_investment}'
            })
        
        if max_investment and amount > max_investment:
            raise drf_serializers.ValidationError({
                'amount': f'Maximum investment is {max_investment}'
            })
        
        # Create investment (status=confirmed triggers blockchain recording via signal)
        investment = serializer.save(user=request.user, status='confirmed')
        
        # Return full investment data including ID
        response_serializer = InvestmentSerializer(investment)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=False, methods=['get'])
    def my_investments(self, request):
        """
        Get current user's investments
        """
        investments = Investment.objects.filter(user=request.user).order_by('-created_at')
        serializer = InvestmentSerializer(investments, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """
        Get investment statistics for current user
        """
        user = request.user
        
        investments = Investment.objects.filter(user=user, status='confirmed')
        
        stats = {
            'total_invested': investments.aggregate(Sum('amount'))['amount__sum'] or 0,
            'total_investments': investments.count(),
            'campaigns_invested': investments.values('campaign').distinct().count(),
            'nfts_owned': investments.filter(nft_minted=True).count(),
            'average_investment': investments.aggregate(Avg('amount'))['amount__avg'] or 0
        }
        
        serializer = InvestmentStatsSerializer(stats)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def blockchain_status(self, request, pk=None):
        """
        Get blockchain recording status for an investment
        """
        investment = self.get_object()
        
        return Response({
            'investment_id': str(investment.id),
            'blockchain_recorded': bool(investment.blockchain_tx_hash),
            'tx_hash': investment.blockchain_tx_hash,
            'recorded_at': investment.blockchain_recorded_at,
            'nft_minted': investment.nft_minted,
            'nft_token_id': investment.nft_token_id
        })
    
    @action(detail=False, methods=['get'])
    def campaign_investments(self, request):
        """
        Get all investments for a specific campaign
        Requires campaign_id query parameter
        """
        campaign_id = request.query_params.get('campaign_id')
        
        if not campaign_id:
            return Response({
                'error': 'campaign_id parameter required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        investments = Investment.objects.filter(
            campaign_id=campaign_id,
            status='confirmed'
        ).order_by('-created_at')
        
        serializer = InvestmentSerializer(investments, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def mint_nft(self, request, pk=None):
        """
        Mint NFT share certificate for an investment
        Generates rich metadata with issuer branding
        """
        from .services.nft_metadata import NFTMetadataGenerator
        from .models import NFTShareCertificate
        
        investment = self.get_object()
        
        # Validate investment
        if investment.status != 'confirmed':
            return Response({
                'error': 'Investment must be confirmed before minting NFT'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if investment.nft_minted:
            return Response({
                'error': 'NFT already minted for this investment',
                'nft_token_id': investment.nft_token_id
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Generate token ID using DB max to ensure proper ordering
        from django.db.models.functions import Cast
        from django.db.models import IntegerField, Max
        
        max_token = NFTShareCertificate.objects.annotate(
            token_id_int=Cast('token_id', IntegerField())
        ).aggregate(max_id=Max('token_id_int'))['max_id']
        token_id = (max_token or 0) + 1
        
        # Generate rich metadata with issuer branding
        metadata = NFTMetadataGenerator.generate_certificate_metadata(
            investment=investment,
            token_id=token_id
        )
        
        # Store NFT record
        nft_certificate = NFTShareCertificate.objects.create(
            investment=investment,
            token_id=str(token_id),
            contract_address='pending',  # Will be updated after blockchain mint
            metadata=metadata,
            voting_weight=metadata.get('voting_power', 1),
            mint_tx_hash='pending'  # Will be updated after blockchain mint
        )
        
        # Update investment
        investment.nft_minted = True
        investment.nft_token_id = str(token_id)
        investment.save()
        
        return Response({
            'message': 'NFT metadata generated successfully',
            'token_id': token_id,
            'metadata': metadata,
            'issuer': metadata.get('issuer', {}),
            'status': 'pending_blockchain_mint'
        }, status=status.HTTP_201_CREATED)
