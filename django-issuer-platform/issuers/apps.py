from django.apps import AppConfig


class IssuersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'issuers'
    verbose_name = 'Issuer Management'
    
    def ready(self):
        """Import signals when app is ready"""
        import issuers.signals
