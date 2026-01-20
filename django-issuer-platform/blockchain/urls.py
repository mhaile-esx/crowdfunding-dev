from django.urls import path
from . import views

urlpatterns = [
    path('health/', views.blockchain_health, name='blockchain-health'),
    path('network/', views.network_info, name='network-info'),
    path('contract/<str:contract_address>/', views.contract_info, name='contract-info'),
]
