from django.urls import path, include
from rest_framework.routers import DefaultRouter
from issuers import views

router = DefaultRouter()
router.register(r'companies', views.CompanyViewSet, basename='company')
router.register(r'profiles', views.IssuerProfileViewSet, basename='issuer-profile')
router.register(r'kyc', views.KYCDocumentViewSet, basename='kyc-document')

urlpatterns = [
    path('', include(router.urls)),
]
