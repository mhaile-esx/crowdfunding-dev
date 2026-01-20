from rest_framework import viewsets, status, permissions, serializers as drf_serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.db import transaction
from django.utils import timezone
from .models import Campaign, CampaignDocument, CampaignUpdate
from .serializers import (
    CampaignSerializer, CampaignCreateSerializer, CampaignDocumentSerializer,
    CampaignUpdateSerializer, CampaignStatsSerializer
)
from .tasks import deploy_campaign_to_blockchain, sync_campaign_stats
from issuers.models import Company


class CampaignViewSet(viewsets.ModelViewSet):
    """
    ViewSet for campaign management
    """
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return CampaignCreateSerializer
        return CampaignSerializer
    
    def get_queryset(self):
        # Handle swagger schema generation
        if getattr(self, 'swagger_fake_view', False):
            return Campaign.objects.none()
        
        user = self.request.user
        
        # Handle anonymous users
        if not user.is_authenticated:
            return Campaign.objects.filter(status='active')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status', None)
        
        if getattr(user, 'role', None) == 'admin':
            queryset = Campaign.objects.all()
        elif getattr(user, 'role', None) == 'issuer':
            queryset = Campaign.objects.filter(company__user=user)
        else:
            queryset = Campaign.objects.filter(status='active')
        
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset.select_related('company', 'approved_by').prefetch_related(
            'documents', 'updates'
        ).order_by('-created_at')
    
    @transaction.atomic
    def perform_create(self, serializer):
        # Get or create company for current user
        company = Company.objects.filter(user=self.request.user).first()
        
        if not company:
            raise drf_serializers.ValidationError({
                'company': 'You must create a company before creating a campaign'
            })
        
        if not company.verified:
            raise drf_serializers.ValidationError({
                'company': 'Company must be verified before creating campaigns'
            })
        
        serializer.save(company=company, status='draft')
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def approve(self, request, pk=None):
        """
        Approve a campaign (admin only)
        Triggers blockchain deployment
        """
        campaign = self.get_object()
        
        if campaign.status != 'draft':
            return Response({
                'error': 'Only draft campaigns can be approved'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            campaign.status = 'approved'
            campaign.approved_by = request.user
            campaign.approved_at = timezone.now()
            campaign.save()
        
        # Trigger async blockchain deployment
        deploy_campaign_to_blockchain.delay(str(campaign.id))
        
        return Response({
            'message': 'Campaign approved. Deploying to blockchain...',
            'campaign': CampaignSerializer(campaign).data
        })
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def reject(self, request, pk=None):
        """
        Reject a campaign (admin only)
        """
        campaign = self.get_object()
        
        campaign.status = 'rejected'
        campaign.save()
        
        return Response({
            'message': 'Campaign rejected',
            'campaign': CampaignSerializer(campaign).data
        })
    
    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """
        Get campaign statistics
        """
        campaign = self.get_object()
        
        # Calculate stats
        progress = (campaign.current_funding / campaign.target_amount * 100) if campaign.target_amount > 0 else 0
        days_remaining = max(0, (campaign.deadline - timezone.now()).days) if campaign.deadline else 0
        
        stats = {
            'total_funding': campaign.current_funding,
            'investor_count': campaign.investor_count,
            'average_investment': campaign.current_funding / campaign.investor_count if campaign.investor_count > 0 else 0,
            'progress_percentage': round(progress, 2),
            'days_remaining': days_remaining,
            'is_successful': campaign.is_successful,
            'blockchain_synced': bool(campaign.smart_contract_address),
            'last_synced': campaign.deployed_at
        }
        
        serializer = CampaignStatsSerializer(stats)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def sync_blockchain(self, request, pk=None):
        """
        Manually sync campaign stats from blockchain
        """
        campaign = self.get_object()
        
        if not campaign.smart_contract_address:
            return Response({
                'error': 'Campaign not deployed to blockchain'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Trigger async sync task
        sync_campaign_stats.delay(str(campaign.id))
        
        return Response({
            'message': 'Blockchain sync initiated'
        })
    
    @action(detail=False, methods=['get'])
    def active(self, request):
        """
        Get all active campaigns
        """
        campaigns = Campaign.objects.filter(status='active').order_by('-created_at')
        serializer = CampaignSerializer(campaigns, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def successful(self, request):
        """
        Get all successful campaigns
        """
        campaigns = Campaign.objects.filter(status='successful').order_by('-created_at')
        serializer = CampaignSerializer(campaigns, many=True)
        return Response(serializer.data)


class CampaignDocumentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for campaign document management
    """
    permission_classes = [IsAuthenticated]
    serializer_class = CampaignDocumentSerializer
    
    def get_queryset(self):
        campaign_id = self.request.query_params.get('campaign', None)
        if campaign_id:
            return CampaignDocument.objects.filter(campaign_id=campaign_id)
        return CampaignDocument.objects.all()
    
    def perform_create(self, serializer):
        serializer.save(uploaded_by=self.request.user)


class CampaignUpdateViewSet(viewsets.ModelViewSet):
    """
    ViewSet for campaign updates
    """
    permission_classes = [IsAuthenticated]
    serializer_class = CampaignUpdateSerializer
    
    def get_queryset(self):
        campaign_id = self.request.query_params.get('campaign', None)
        if campaign_id:
            return CampaignUpdate.objects.filter(campaign_id=campaign_id).order_by('-posted_at')
        return CampaignUpdate.objects.all().order_by('-posted_at')
    
    def perform_create(self, serializer):
        serializer.save(posted_by=self.request.user)
