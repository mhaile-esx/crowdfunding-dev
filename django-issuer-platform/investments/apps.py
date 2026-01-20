from django.apps import AppConfig


class InvestmentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'investments'
    verbose_name = 'Investment Management'
    
    def ready(self):
        """Import signals when app is ready"""
        import investments.signals
