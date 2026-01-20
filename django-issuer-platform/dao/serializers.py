from rest_framework import serializers
from .models import DAOProposal, DAOVote
from issuers.serializers import UserSerializer

class DAOProposalSerializer(serializers.ModelSerializer):
    proposer_info = UserSerializer(source='proposer', read_only=True)
    total_votes = serializers.DecimalField(max_digits=20, decimal_places=0, read_only=True)
    is_active = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = DAOProposal
        fields = '__all__'
        read_only_fields = ['id', 'votes_for', 'votes_against', 'executed', 'executed_at', 'created_at', 'updated_at']

class DAOProposalCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DAOProposal
        fields = ['title', 'description', 'proposal_type', 'campaign', 'voting_duration', 'quorum', 'metadata']
    
    def create(self, validated_data):
        user = self.context['request'].user
        validated_data['proposer'] = user
        validated_data['proposer_address'] = user.wallet_address or ''
        validated_data['status'] = 'active'
        return super().create(validated_data)

class DAOVoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = DAOVote
        fields = '__all__'

class DAOVoteCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DAOVote
        fields = ['proposal', 'support', 'transaction_hash']
    
    def create(self, validated_data):
        from .services import DAOVotingService
        user = self.context['request'].user
        voting_power = DAOVotingService.get_voting_power(user.wallet_address)
        validated_data['voter'] = user
        validated_data['voter_address'] = user.wallet_address
        validated_data['voting_power'] = voting_power
        vote = super().create(validated_data)
        proposal = vote.proposal
        if vote.support:
            proposal.votes_for += vote.voting_power
        else:
            proposal.votes_against += vote.voting_power
        proposal.save()
        return vote
