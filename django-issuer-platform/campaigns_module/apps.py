"""
Django app configuration for Campaign Module
"""
from django.apps import AppConfig


class CampaignsModuleConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'campaigns_module'
    verbose_name = 'Campaign Management'
    
    def ready(self):
        import campaigns_module.signals
