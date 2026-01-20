"""
WSGI config for issuer_platform project.
"""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'issuer_platform.settings')

application = get_wsgi_application()
