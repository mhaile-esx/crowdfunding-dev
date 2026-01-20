"""
Wallet Service for Server-Side Wallet Generation
Generates and manages encrypted wallets for users without MetaMask
"""
from eth_account import Account
from web3 import Web3
from cryptography.fernet import Fernet
from django.conf import settings
import logging
import os

logger = logging.getLogger('blockchain')


class WalletService:
    """
    Service for generating and managing blockchain wallets
    Private keys are encrypted using Fernet symmetric encryption
    
    SECURITY REQUIREMENTS:
    - WALLET_ENCRYPTION_KEY must be set in production
    - Key should be 32 bytes, URL-safe base64-encoded
    - Generate with: from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())
    - Store securely in environment/secrets manager
    """
    
    def __init__(self):
        encryption_key = os.getenv('WALLET_ENCRYPTION_KEY')
        if encryption_key:
            try:
                key_bytes = encryption_key.encode() if isinstance(encryption_key, str) else encryption_key
                self.fernet = Fernet(key_bytes)
                self.encryption_enabled = True
            except Exception as e:
                logger.error(f"Invalid WALLET_ENCRYPTION_KEY format: {e}")
                raise ValueError("WALLET_ENCRYPTION_KEY must be a valid Fernet key")
        else:
            logger.error("CRITICAL: WALLET_ENCRYPTION_KEY not set - wallet generation disabled for security")
            self.fernet = None
            self.encryption_enabled = False
    
    def generate_wallet(self) -> dict:
        if not self.encryption_enabled:
            raise ValueError("Wallet generation requires WALLET_ENCRYPTION_KEY to be configured")
        
        account = Account.create()
        encrypted_key = self.fernet.encrypt(account.key.hex().encode())
        
        wallet_data = {
            'address': account.address,
            'encrypted_private_key': encrypted_key.decode(),
        }
        
        logger.info(f"Generated new wallet: {account.address}")
        return wallet_data
    
    def decrypt_private_key(self, encrypted_key: str) -> str:
        if not self.fernet:
            raise ValueError("Encryption not configured")
        return self.fernet.decrypt(encrypted_key.encode()).decode()
    
    def get_balance(self, address: str) -> dict:
        from .web3_client import get_blockchain_client
        
        try:
            client = get_blockchain_client()
            balance_wei = client.w3.eth.get_balance(address)
            balance_eth = Web3.from_wei(balance_wei, 'ether')
            
            return {
                'address': address,
                'balance_wei': str(balance_wei),
                'balance_eth': str(balance_eth),
            }
        except Exception as e:
            logger.error(f"Failed to get balance for {address}: {e}")
            return {'address': address, 'balance_wei': '0', 'balance_eth': '0', 'error': str(e)}


_wallet_service = None

def get_wallet_service() -> WalletService:
    global _wallet_service
    if _wallet_service is None:
        _wallet_service = WalletService()
    return _wallet_service
