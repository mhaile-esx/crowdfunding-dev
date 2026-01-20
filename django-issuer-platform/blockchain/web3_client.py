"""
Web3.py client for Polygon Edge blockchain integration
FIXED: Addresses critical issues from architect review
"""
from web3 import Web3
from eth_account import Account

# Handle different web3.py versions
try:
    # web3.py v6.x
    from web3.middleware import ExtraDataToPOAMiddleware
    POA_MIDDLEWARE = ExtraDataToPOAMiddleware
except ImportError:
    try:
        # web3.py v7.x+
        from web3.middleware import extradata_to_poa_middleware
        POA_MIDDLEWARE = extradata_to_poa_middleware
    except ImportError:
        # Fallback - no POA middleware needed for some setups
        POA_MIDDLEWARE = None
from django.conf import settings
import logging
from typing import Dict, Any, Optional, List
from decimal import Decimal

logger = logging.getLogger('blockchain')


class BlockchainError(Exception):
    """Base exception for blockchain errors"""
    pass


class TransactionFailed(BlockchainError):
    """Transaction failed on blockchain"""
    pass


class BlockchainTimeout(BlockchainError):
    """Blockchain operation timed out"""
    pass


class PolygonEdgeClient:
    """
    Web3.py client for interacting with Polygon Edge blockchain
    FIXED: Updated for Web3.py v6+ with proper error handling
    """
    
    def __init__(self):
        self.rpc_url = settings.BLOCKCHAIN_SETTINGS['POLYGON_EDGE_RPC_URL']
        self.chain_id = settings.BLOCKCHAIN_SETTINGS['CHAIN_ID']
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        
        # FIX 1: Use correct middleware for PoA chains (compatible with web3.py v6 and v7)
        if POA_MIDDLEWARE:
            self.w3.middleware_onion.inject(POA_MIDDLEWARE, layer=0)
        
        # Initialize account from private key
        private_key = settings.BLOCKCHAIN_SETTINGS.get('DEPLOYER_PRIVATE_KEY')
        if private_key:
            self.account = Account.from_key(private_key)
            self.deployer_address = self.account.address
        else:
            self.account = None
            self.deployer_address = settings.BLOCKCHAIN_SETTINGS.get('DEPLOYER_ADDRESS')
        
        # Contract addresses
        self.contracts = {
            'issuer_registry': settings.SMART_CONTRACTS.get('ISSUER_REGISTRY'),
            'campaign_factory': settings.SMART_CONTRACTS.get('CAMPAIGN_FACTORY'),
            'fund_escrow': settings.SMART_CONTRACTS.get('FUND_ESCROW'),
            'nft_certificate': settings.SMART_CONTRACTS.get('NFT_CERTIFICATE'),
        }
        
        logger.info(f"Initialized Polygon Edge client: {self.rpc_url}")
        logger.info(f"Chain ID: {self.chain_id}")
        logger.info(f"Deployer Address: {self.deployer_address}")
    
    def is_connected(self) -> bool:
        """Check if connected to the network"""
        try:
            return self.w3.is_connected()
        except Exception as e:
            logger.error(f"Connection check failed: {e}")
            return False
    
    def get_network_info(self) -> Dict[str, Any]:
        """Get basic network information"""
        try:
            return {
                'connected': self.is_connected(),
                'chain_id': self.w3.eth.chain_id,
                'latest_block': self.w3.eth.block_number,
                'gas_price': str(self.w3.eth.gas_price),
                'deployer_balance': str(self.w3.eth.get_balance(self.deployer_address)),
            }
        except Exception as e:
            logger.error(f"Failed to get network info: {e}")
            return {'connected': False, 'error': str(e)}
    
    def get_contract_instance(self, contract_name: str, address: Optional[str] = None):
        """
        Get a contract instance
        FIX 2: Use embedded ABIs instead of external files
        
        Args:
            contract_name: Name of the contract (issuer_registry, campaign_factory, etc.)
            address: Optional custom address (for campaign instances)
        """
        contract_address = address or self.contracts.get(contract_name)
        if not contract_address:
            raise ValueError(f"Contract address not found for {contract_name}")
        
        # FIX 2: Import ABIs from Python module (no file I/O)
        from blockchain.abis import get_abi
        
        try:
            abi = get_abi(contract_name)
        except KeyError:
            logger.error(f"ABI not found for contract: {contract_name}")
            raise ValueError(f"ABI not found for contract: {contract_name}")
        
        return self.w3.eth.contract(address=contract_address, abi=abi)
    
    def send_transaction(
        self,
        contract_function,
        from_address: Optional[str] = None,
        value: int = 0,
        gas_limit: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Send a transaction to the blockchain
        FIX 3: Honor configured gas price and add error handling
        FIX 4: Add timeout and transaction failure detection
        
        Args:
            contract_function: Web3 contract function to call
            from_address: Sender address (defaults to deployer)
            value: ETH value to send (in Wei)
            gas_limit: Custom gas limit
            
        Returns:
            Dict with txHash, blockNumber, gasUsed, status
            
        Raises:
            TransactionFailed: If transaction fails
            BlockchainTimeout: If transaction times out
        """
        if not self.account:
            raise ValueError("Private key not configured")
        
        from_address = from_address or self.deployer_address
        
        # FIX 3: Honor configured gas price
        gas_price = self.w3.eth.gas_price
        configured_gas_price = settings.BLOCKCHAIN_SETTINGS.get('GAS_PRICE')
        if configured_gas_price:
            gas_price = max(gas_price, configured_gas_price)
        
        # Build transaction
        tx = contract_function.build_transaction({
            'from': from_address,
            'value': value,
            'gas': gas_limit or settings.BLOCKCHAIN_SETTINGS['GAS_LIMIT'],
            'gasPrice': gas_price,  # FIX 3: Use properly calculated gas price
            'nonce': self.w3.eth.get_transaction_count(from_address),
            'chainId': self.chain_id,
        })
        
        # Sign transaction
        signed_tx = self.account.sign_transaction(tx)
        
        # Send transaction
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        logger.info(f"Transaction sent: {tx_hash.hex()}")
        
        # FIX 4: Wait for receipt with timeout and error handling
        try:
            receipt = self.w3.eth.wait_for_transaction_receipt(
                tx_hash,
                timeout=120  # 2 minute timeout
            )
        except TimeoutError:
            logger.error(f"Transaction timeout: {tx_hash.hex()}")
            raise BlockchainTimeout(f"Transaction timeout: {tx_hash.hex()}")
        
        # FIX 4: Check if transaction failed
        if receipt['status'] == 0:
            logger.error(f"Transaction failed: {tx_hash.hex()}")
            raise TransactionFailed(f"Transaction failed: {tx_hash.hex()}")
        
        logger.info(f"Transaction successful: {tx_hash.hex()} in block {receipt['blockNumber']}")
        
        return {
            'txHash': tx_hash.hex(),
            'blockNumber': receipt['blockNumber'],
            'gasUsed': receipt['gasUsed'],
            'status': receipt['status'],
            'contractAddress': receipt.get('contractAddress'),
            'logs': receipt.get('logs', []),
        }
    
    def call_function(self, contract_function) -> Any:
        """
        Call a read-only contract function
        
        Args:
            contract_function: Web3 contract function to call
            
        Returns:
            Function return value
        """
        return contract_function.call()
    
    def get_transaction_receipt(self, tx_hash: str) -> Dict[str, Any]:
        """Get transaction receipt"""
        receipt = self.w3.eth.get_transaction_receipt(tx_hash)
        return {
            'txHash': receipt['transactionHash'].hex(),
            'blockNumber': receipt['blockNumber'],
            'gasUsed': receipt['gasUsed'],
            'status': receipt['status'],
            'from': receipt['from'],
            'to': receipt['to'],
            'contractAddress': receipt.get('contractAddress'),
            'logs': receipt.get('logs', []),
        }
    
    def get_logs(
        self,
        contract_address: str,
        event_name: str,
        from_block: int = 0,
        to_block: str = 'latest'
    ) -> List[Dict]:
        """
        Get event logs from blockchain
        
        Args:
            contract_address: Contract address
            event_name: Event name to filter
            from_block: Starting block number
            to_block: Ending block ('latest' for current)
            
        Returns:
            List of event logs
        """
        try:
            logs = self.w3.eth.get_logs({
                'address': contract_address,
                'fromBlock': from_block,
                'toBlock': to_block,
            })
            return logs
        except Exception as e:
            logger.error(f"Failed to get logs: {e}")
            return []
    
    def parse_event_log(self, contract_name: str, event_name: str, log: Dict) -> Optional[Dict]:
        """
        Parse an event log
        
        Args:
            contract_name: Contract name
            event_name: Event name
            log: Raw log entry
            
        Returns:
            Parsed event data or None if parsing fails
        """
        try:
            contract = self.get_contract_instance(contract_name)
            event = getattr(contract.events, event_name)()
            return event.process_log(log)
        except Exception as e:
            logger.error(f"Failed to parse event {event_name}: {e}")
            return None


# Global singleton instance
_client = None


def get_blockchain_client() -> PolygonEdgeClient:
    """Get or create blockchain client singleton"""
    global _client
    if _client is None:
        _client = PolygonEdgeClient()
    return _client
