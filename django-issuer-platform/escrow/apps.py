"""
Django app configuration for Escrow Module
"""
from django.apps import AppConfig


class EscrowConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'escrow'
    verbose_name = 'Fund Escrow Management'
    
    def ready(self):
        import escrow.signals
