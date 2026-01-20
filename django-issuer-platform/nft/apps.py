"""
Django app configuration for NFT Module
"""
from django.apps import AppConfig


class NftConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nft'
    verbose_name = 'NFT Share Certificates'
    
    def ready(self):
        import nft.signals
