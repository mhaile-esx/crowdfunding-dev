from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'proposals', views.DAOProposalViewSet, basename='dao-proposal')
router.register(r'votes', views.DAOVoteViewSet, basename='dao-vote')
router.register(r'voting-power', views.VotingPowerView, basename='voting-power')

urlpatterns = [path('', include(router.urls))]
