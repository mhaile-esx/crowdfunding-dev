"""
Backoffice administration views for reviewing issuers, KYC documents, and campaigns
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta

from .permissions import IsAdminOrComplianceOfficer, IsAdminOnly
from .serializers import (
    AdminUserSerializer, AdminCompanySerializer, AdminKYCDocumentSerializer,
    AdminCampaignSerializer, KYCReviewSerializer, CampaignReviewSerializer,
    CompanyReviewSerializer, DashboardStatsSerializer
)
from issuers.models import Company, User, KYCDocument, IssuerProfile
from campaigns_module.models import Campaign


class AdminDashboardViewSet(viewsets.ViewSet):
    """
    Dashboard endpoints for backoffice administrators
    """
    permission_classes = [IsAuthenticated, IsAdminOrComplianceOfficer]
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """
        Get dashboard statistics for admin overview
        """
        pending_issuers = Company.objects.filter(verified=False).count()
        pending_kyc = KYCDocument.objects.filter(status='pending').count()
        pending_campaigns = Campaign.objects.filter(status='pending').count()
        active_campaigns = Campaign.objects.filter(status='active').count()
        total_issuers = User.objects.filter(role='issuer').count()
        total_investors = User.objects.filter(role='investor').count()
        
        total_funding = Campaign.objects.filter(
            status__in=['active', 'successful']
        ).aggregate(total=Sum('current_funding'))['total'] or 0
        
        recent_activities = []
        
        recent_issuers = Company.objects.order_by('-created_at')[:5]
        for issuer in recent_issuers:
            recent_activities.append({
                'type': 'issuer_registration',
                'description': f"New issuer registered: {issuer.name}",
                'timestamp': issuer.created_at.isoformat(),
                'id': str(issuer.id)
            })
        
        recent_campaigns = Campaign.objects.order_by('-created_at')[:5]
        for campaign in recent_campaigns:
            recent_activities.append({
                'type': 'campaign_created',
                'description': f"Campaign created: {campaign.title}",
                'timestamp': campaign.created_at.isoformat(),
                'id': str(campaign.id)
            })
        
        recent_activities.sort(key=lambda x: x['timestamp'], reverse=True)
        
        data = {
            'pending_issuers': pending_issuers,
            'pending_kyc_documents': pending_kyc,
            'pending_campaigns': pending_campaigns,
            'active_campaigns': active_campaigns,
            'total_issuers': total_issuers,
            'total_investors': total_investors,
            'total_funding_raised': total_funding,
            'recent_activities': recent_activities[:10]
        }
        
        return Response(DashboardStatsSerializer(data).data)
    
    @action(detail=False, methods=['get'])
    def pending_queue(self, request):
        """
        Get all pending items requiring review
        """
        queue = {
            'issuers': AdminCompanySerializer(
                Company.objects.filter(verified=False).order_by('created_at'),
                many=True
            ).data,
            'kyc_documents': AdminKYCDocumentSerializer(
                KYCDocument.objects.filter(status='pending').order_by('created_at'),
                many=True
            ).data,
            'campaigns': AdminCampaignSerializer(
                Campaign.objects.filter(status='pending').order_by('created_at'),
                many=True
            ).data
        }
        return Response(queue)


class IssuerReviewViewSet(viewsets.ModelViewSet):
    """
    ViewSet for reviewing and managing issuer submissions
    """
    permission_classes = [IsAuthenticated, IsAdminOrComplianceOfficer]
    serializer_class = AdminCompanySerializer
    
    def get_queryset(self):
        queryset = Company.objects.all().select_related('user')
        
        status_filter = self.request.query_params.get('status')
        if status_filter == 'pending':
            queryset = queryset.filter(verified=False)
        elif status_filter == 'verified':
            queryset = queryset.filter(verified=True)
        
        sector = self.request.query_params.get('sector')
        if sector:
            queryset = queryset.filter(sector=sector)
        
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) |
                Q(tin_number__icontains=search)
            )
        
        return queryset.order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        """
        Review and take action on an issuer submission
        
        Actions:
        - verify: Approve the issuer
        - reject: Reject the issuer
        - request_documents: Request additional documents
        """
        company = self.get_object()
        serializer = CompanyReviewSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        action_type = serializer.validated_data['action']
        
        if action_type == 'verify':
            company.verified = True
            company.save()
            
            return Response({
                'message': f"Issuer '{company.name}' has been verified",
                'company': AdminCompanySerializer(company).data
            })
        
        elif action_type == 'reject':
            reason = serializer.validated_data.get('rejection_reason', 'Application rejected')
            company.verified = False
            company.save()
            
            return Response({
                'message': f"Issuer '{company.name}' has been rejected",
                'reason': reason,
                'company': AdminCompanySerializer(company).data
            })
        
        elif action_type == 'request_documents':
            required_docs = serializer.validated_data.get('required_documents', [])
            
            return Response({
                'message': f"Additional documents requested for '{company.name}'",
                'required_documents': required_docs,
                'company': AdminCompanySerializer(company).data
            })
    
    @action(detail=True, methods=['get'])
    def documents(self, request, pk=None):
        """
        Get all KYC documents for an issuer
        """
        company = self.get_object()
        documents = KYCDocument.objects.filter(
            Q(company=company) | Q(user=company.user)
        ).order_by('-created_at')
        
        return Response(AdminKYCDocumentSerializer(documents, many=True).data)
    
    @action(detail=True, methods=['get'])
    def campaigns(self, request, pk=None):
        """
        Get all campaigns for an issuer
        """
        company = self.get_object()
        campaigns = company.campaigns.all().order_by('-created_at')
        
        return Response(AdminCampaignSerializer(campaigns, many=True).data)


class KYCReviewViewSet(viewsets.ModelViewSet):
    """
    ViewSet for reviewing KYC documents
    """
    permission_classes = [IsAuthenticated, IsAdminOrComplianceOfficer]
    serializer_class = AdminKYCDocumentSerializer
    
    def get_queryset(self):
        queryset = KYCDocument.objects.all().select_related('user', 'company')
        
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        doc_type = self.request.query_params.get('document_type')
        if doc_type:
            queryset = queryset.filter(document_type=doc_type)
        
        return queryset.order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        """
        Review and take action on a KYC document
        
        Actions:
        - approve: Approve the document and update user KYC level
        - reject: Reject the document with reason
        """
        document = self.get_object()
        serializer = KYCReviewSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        action_type = serializer.validated_data['action']
        
        if action_type == 'approve':
            document.status = 'verified'
            document.verified_by = request.user
            document.verified_at = timezone.now()
            document.save()
            
            kyc_level = serializer.validated_data.get('kyc_level', 'basic')
            user = document.user
            user.kyc_level = kyc_level
            user.kyc_verified = True
            user.kyc_verified_at = timezone.now()
            user.save()
            
            return Response({
                'message': f"KYC document approved for {user.username}",
                'kyc_level': kyc_level,
                'document': AdminKYCDocumentSerializer(document).data
            })
        
        elif action_type == 'reject':
            reason = serializer.validated_data.get('rejection_reason', 'Document rejected')
            document.status = 'rejected'
            document.verified_by = request.user
            document.verified_at = timezone.now()
            document.rejection_reason = reason
            document.save()
            
            return Response({
                'message': f"KYC document rejected for {document.user.username}",
                'reason': reason,
                'document': AdminKYCDocumentSerializer(document).data
            })
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """
        Get KYC document review statistics
        """
        total = KYCDocument.objects.count()
        pending = KYCDocument.objects.filter(status='pending').count()
        verified = KYCDocument.objects.filter(status='verified').count()
        rejected = KYCDocument.objects.filter(status='rejected').count()
        
        by_type = KYCDocument.objects.values('document_type').annotate(
            count=Count('id')
        )
        
        return Response({
            'total': total,
            'pending': pending,
            'verified': verified,
            'rejected': rejected,
            'by_document_type': list(by_type)
        })


class CampaignReviewViewSet(viewsets.ModelViewSet):
    """
    ViewSet for reviewing campaign submissions
    """
    permission_classes = [IsAuthenticated, IsAdminOrComplianceOfficer]
    serializer_class = AdminCampaignSerializer
    
    def get_queryset(self):
        queryset = Campaign.objects.all().select_related('company', 'company__user')
        
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        approved_filter = self.request.query_params.get('approved')
        if approved_filter is not None:
            queryset = queryset.filter(approved=approved_filter.lower() == 'true')
        
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) |
                Q(company__name__icontains=search)
            )
        
        return queryset.order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        """
        Review and take action on a campaign submission
        
        Actions:
        - approve: Approve the campaign for launch
        - reject: Reject the campaign with reason
        - request_changes: Request changes before approval
        """
        campaign = self.get_object()
        serializer = CampaignReviewSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        action_type = serializer.validated_data['action']
        
        if action_type == 'approve':
            if not campaign.company.verified:
                return Response({
                    'error': "Cannot approve campaign - issuer company is not verified"
                }, status=status.HTTP_400_BAD_REQUEST)
            
            campaign.approved = True
            campaign.approved_at = timezone.now()
            campaign.approved_by = request.user
            campaign.status = 'pending'
            campaign.save()
            
            return Response({
                'message': f"Campaign '{campaign.title}' has been approved",
                'campaign': AdminCampaignSerializer(campaign).data
            })
        
        elif action_type == 'reject':
            reason = serializer.validated_data.get('rejection_reason', 'Campaign rejected')
            campaign.status = 'cancelled'
            campaign.approved = False
            campaign.save()
            
            return Response({
                'message': f"Campaign '{campaign.title}' has been rejected",
                'reason': reason,
                'campaign': AdminCampaignSerializer(campaign).data
            })
        
        elif action_type == 'request_changes':
            notes = serializer.validated_data.get('review_notes', '')
            
            return Response({
                'message': f"Changes requested for campaign '{campaign.title}'",
                'notes': notes,
                'campaign': AdminCampaignSerializer(campaign).data
            })
    
    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        """
        Activate an approved campaign (start accepting investments)
        """
        campaign = self.get_object()
        
        if not campaign.approved:
            return Response({
                'error': "Campaign must be approved before activation"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if campaign.status == 'active':
            return Response({
                'error': "Campaign is already active"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        campaign.status = 'active'
        campaign.start_date = timezone.now()
        campaign.end_date = timezone.now() + timedelta(days=campaign.duration)
        campaign.save()
        
        campaign.company.has_active_campaign = True
        campaign.company.active_campaign_id = campaign.id
        campaign.company.save()
        
        return Response({
            'message': f"Campaign '{campaign.title}' is now active",
            'start_date': campaign.start_date.isoformat(),
            'end_date': campaign.end_date.isoformat(),
            'campaign': AdminCampaignSerializer(campaign).data
        })
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """
        Get campaign review statistics
        """
        total = Campaign.objects.count()
        by_status = Campaign.objects.values('status').annotate(count=Count('id'))
        
        total_goal = Campaign.objects.aggregate(Sum('funding_goal'))['funding_goal__sum'] or 0
        total_raised = Campaign.objects.aggregate(Sum('current_funding'))['current_funding__sum'] or 0
        
        return Response({
            'total': total,
            'by_status': list(by_status),
            'total_funding_goal': total_goal,
            'total_funding_raised': total_raised,
            'avg_success_rate': (total_raised / total_goal * 100) if total_goal > 0 else 0
        })


class UserManagementViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing users (admin only)
    """
    permission_classes = [IsAuthenticated, IsAdminOnly]
    serializer_class = AdminUserSerializer
    
    def get_queryset(self):
        queryset = User.objects.all()
        
        role = self.request.query_params.get('role')
        if role:
            queryset = queryset.filter(role=role)
        
        kyc_verified = self.request.query_params.get('kyc_verified')
        if kyc_verified is not None:
            queryset = queryset.filter(kyc_verified=kyc_verified.lower() == 'true')
        
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search)
            )
        
        return queryset.order_by('-date_joined')
    
    @action(detail=True, methods=['post'])
    def change_role(self, request, pk=None):
        """
        Change a user's role
        """
        user = self.get_object()
        new_role = request.data.get('role')
        
        valid_roles = ['admin', 'compliance_officer', 'custodian', 'regulator', 'issuer', 'investor']
        if new_role not in valid_roles:
            return Response({
                'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        old_role = user.role
        user.role = new_role
        user.save()
        
        return Response({
            'message': f"User role changed from '{old_role}' to '{new_role}'",
            'user': AdminUserSerializer(user).data
        })
    
    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """
        Enable/disable a user account
        """
        user = self.get_object()
        
        if user == request.user:
            return Response({
                'error': "Cannot deactivate your own account"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        user.is_active = not user.is_active
        user.save()
        
        status_text = 'activated' if user.is_active else 'deactivated'
        
        return Response({
            'message': f"User account {status_text}",
            'user': AdminUserSerializer(user).data
        })
