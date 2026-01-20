"""
Smart Contract ABIs
FIX: Embedded as Python constants (no external file dependencies)
"""
from .issuer_registry import ISSUER_REGISTRY_ABI
from .campaign_factory import CAMPAIGN_FACTORY_ABI
from .campaign_implementation import CAMPAIGN_IMPLEMENTATION_ABI
from .nft_certificate import NFT_CERTIFICATE_ABI
from .fund_escrow import FUND_ESCROW_ABI


# ABI registry
_ABIS = {
    'issuer_registry': ISSUER_REGISTRY_ABI,
    'campaign_factory': CAMPAIGN_FACTORY_ABI,
    'campaign_implementation': CAMPAIGN_IMPLEMENTATION_ABI,
    'nft_certificate': NFT_CERTIFICATE_ABI,
    'fund_escrow': FUND_ESCROW_ABI,
}


def get_abi(contract_name: str) -> list:
    """
    Get ABI for a contract by name
    
    Args:
        contract_name: Contract name (issuer_registry, campaign_factory, etc.)
        
    Returns:
        ABI list
        
    Raises:
        KeyError: If contract name not found
    """
    if contract_name not in _ABIS:
        raise KeyError(f"ABI not found for contract: {contract_name}")
    return _ABIS[contract_name]
