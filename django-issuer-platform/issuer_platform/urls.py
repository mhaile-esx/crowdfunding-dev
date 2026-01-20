from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

# Health check endpoint for Docker/load balancer
def health_check(request):
    return JsonResponse({'status': 'healthy', 'service': 'crowdfundchain-api'})

# API Documentation
schema_view = get_schema_view(
    openapi.Info(
        title="CrowdfundChain Issuer Platform API",
        default_version='v1',
        description="Blockchain-powered crowdfunding platform for African SMEs and startups",
        terms_of_service="https://crowdfundchain.com/terms/",
        contact=openapi.Contact(email="api@crowdfundchain.com"),
        license=openapi.License(name="MIT License"),
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    # Health check endpoint (for Docker/Kubernetes)
    path('health/', health_check, name='health_check'),
    
    # Django Admin
    path('admin/', admin.site.urls),
    
    # API Documentation
    path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('api/redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    
    # Authentication endpoints
    path('api/auth/', include('issuers.urls.auth_urls')),
    
    # Issuer management endpoints
    path('api/issuers/', include('issuers.urls.issuer_urls')),
    
    # Campaign management endpoints
    path('api/campaigns/', include('campaigns_module.urls')),
    
    # Investment endpoints
    path('api/investments/', include('investments.urls')),
    
    # Escrow management endpoints
    path('api/escrow/', include('escrow.urls')),
    
    # NFT certificate endpoints (served by investments app)
    # path('api/nft/', include('nft.urls')),  # Disabled - NFT functionality in investments
    
    # Blockchain status endpoints
    path('api/blockchain/', include('blockchain.urls')),
    
    # DAO Governance
    path('api/dao/', include('dao.urls')),
]
