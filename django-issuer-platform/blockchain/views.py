from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from .web3_client import get_blockchain_client
from django.conf import settings


@api_view(['GET'])
@permission_classes([AllowAny])
def blockchain_health(request):
    """
    Check blockchain network health
    """
    try:
        client = get_blockchain_client()
        
        is_connected = client.w3.is_connected()
        
        if not is_connected:
            return Response({
                'status': 'disconnected',
                'connected': False,
                'message': 'Unable to connect to blockchain network'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        # Get network info
        block_number = client.w3.eth.block_number
        chain_id = client.w3.eth.chain_id
        
        return Response({
            'status': 'healthy',
            'connected': True,
            'network': {
                'chain_id': chain_id,
                'block_number': block_number,
                'rpc_url': settings.BLOCKCHAIN_SETTINGS['POLYGON_EDGE_RPC_URL']
            }
        })
    
    except Exception as e:
        return Response({
            'status': 'error',
            'connected': False,
            'error': str(e)
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)


@api_view(['GET'])
@permission_classes([AllowAny])
def network_info(request):
    """
    Get detailed blockchain network information
    """
    try:
        client = get_blockchain_client()
        
        # Get latest block
        latest_block = client.w3.eth.get_block('latest')
        
        # Get contract addresses
        contracts = settings.SMART_CONTRACTS
        
        return Response({
            'network': {
                'chain_id': client.w3.eth.chain_id,
                'rpc_url': settings.BLOCKCHAIN_SETTINGS['POLYGON_EDGE_RPC_URL'],
                'block_number': latest_block['number'],
                'block_timestamp': latest_block['timestamp'],
                'gas_price': str(client.w3.eth.gas_price)
            },
            'contracts': {
                'nft_certificate': contracts.get('NFT_CERTIFICATE'),
                'dao_governance': contracts.get('DAO_GOVERNANCE'),
                'campaign_factory': contracts.get('CAMPAIGN_FACTORY'),
                'campaign_implementation': contracts.get('CAMPAIGN_IMPLEMENTATION')
            }
        })
    
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
def contract_info(request, contract_address):
    """
    Get information about a specific contract
    """
    try:
        client = get_blockchain_client()
        
        # Get contract code
        code = client.w3.eth.get_code(contract_address)
        
        if code == b'' or code == '0x':
            return Response({
                'error': 'No contract found at this address'
            }, status=status.HTTP_404_NOT_FOUND)
        
        return Response({
            'contract_address': contract_address,
            'code_size': len(code),
            'is_contract': True
        })
    
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
