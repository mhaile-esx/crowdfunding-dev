from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import DAOProposal, DAOVote
from .serializers import DAOProposalSerializer, DAOProposalCreateSerializer, DAOVoteSerializer, DAOVoteCreateSerializer
from .services import DAOVotingService

class DAOProposalViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    queryset = DAOProposal.objects.all()
    
    def get_serializer_class(self):
        if self.action == 'create':
            return DAOProposalCreateSerializer
        return DAOProposalSerializer
    
    @action(detail=True, methods=['get'])
    def votes(self, request, pk=None):
        proposal = self.get_object()
        votes = proposal.votes.all()
        return Response(DAOVoteSerializer(votes, many=True).data)

class DAOVoteViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = DAOVoteSerializer
    
    def get_queryset(self):
        return DAOVote.objects.filter(voter=self.request.user)
    
    def get_serializer_class(self):
        if self.action == 'create':
            return DAOVoteCreateSerializer
        return DAOVoteSerializer
    
    @action(detail=False, methods=['get'])
    def check(self, request):
        proposal_id = request.query_params.get('proposalId')
        voter_address = request.user.wallet_address
        try:
            vote = DAOVote.objects.get(proposal_id=proposal_id, voter_address__iexact=voter_address)
            return Response({'hasVoted': True, 'vote': DAOVoteSerializer(vote).data})
        except DAOVote.DoesNotExist:
            return Response({'hasVoted': False, 'vote': None})

class VotingPowerView(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]
    
    def retrieve(self, request, pk=None):
        address = pk if pk != 'me' else request.user.wallet_address
        breakdown = DAOVotingService.get_voting_power_breakdown(address)
        return Response({'address': address, **breakdown})
