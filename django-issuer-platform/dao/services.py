from decimal import Decimal
from django.db.models import Sum
from investments.models import Investment

class DAOVotingService:
    VOTING_POWER_PER_ETB = Decimal('0.001')
    
    @classmethod
    def get_voting_power(cls, wallet_address):
        if not wallet_address:
            return Decimal('0')
        from issuers.models import User
        try:
            user = User.objects.get(wallet_address__iexact=wallet_address)
        except User.DoesNotExist:
            return Decimal('0')
        total = Investment.objects.filter(user=user, status='confirmed').aggregate(total=Sum('amount'))['total'] or Decimal('0')
        return total * cls.VOTING_POWER_PER_ETB
    
    @classmethod
    def get_voting_power_breakdown(cls, wallet_address):
        power = cls.get_voting_power(wallet_address)
        return {
            'total_power': str(int(power)),
            'sources': {'nft_shares': '0', 'investments': str(int(power)), 'reputation_score': '0'}
        }
