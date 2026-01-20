from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'certificates', views.NFTShareCertificateViewSet, basename='nft-certificate')
router.register(r'transfers', views.NFTTransferHistoryViewSet, basename='nft-transfer')

urlpatterns = [
    path('', include(router.urls)),
]
