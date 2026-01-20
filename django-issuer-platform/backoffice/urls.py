"""
URL configuration for backoffice administration
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AdminDashboardViewSet,
    IssuerReviewViewSet,
    KYCReviewViewSet,
    CampaignReviewViewSet,
    UserManagementViewSet
)

router = DefaultRouter()
router.register(r'dashboard', AdminDashboardViewSet, basename='admin-dashboard')
router.register(r'issuers', IssuerReviewViewSet, basename='admin-issuers')
router.register(r'kyc', KYCReviewViewSet, basename='admin-kyc')
router.register(r'campaigns', CampaignReviewViewSet, basename='admin-campaigns')
router.register(r'users', UserManagementViewSet, basename='admin-users')

urlpatterns = [
    path('', include(router.urls)),
]
