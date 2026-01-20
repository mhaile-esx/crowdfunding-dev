from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'', views.CampaignViewSet, basename='campaign')
router.register(r'documents', views.CampaignDocumentViewSet, basename='campaign-document')
router.register(r'updates', views.CampaignUpdateViewSet, basename='campaign-update')

urlpatterns = [
    path('', include(router.urls)),
]
