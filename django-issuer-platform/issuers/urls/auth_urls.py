from django.urls import path
from issuers import views
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
    TokenVerifyView,
)

urlpatterns = [
    # JWT Token endpoints
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    
    # Traditional auth endpoints
    path('register/', views.register_user, name='register'),
    path('login/', views.login_user, name='login'),
    path('logout/', views.logout_user, name='logout'),
    path('me/', views.current_user, name='current-user'),
    path('wallet-connect/', views.connect_wallet, name='connect-wallet'),
    path('wallet/generate/', views.generate_wallet, name='generate-wallet'),
    path('wallet/balance/', views.wallet_balance, name='wallet-balance'),
]
