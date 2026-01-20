from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'escrow', views.FundEscrowViewSet, basename='fund-escrow')
router.register(r'refunds', views.RefundTransactionViewSet, basename='refund-transaction')

urlpatterns = [
    path('', include(router.urls)),
]
