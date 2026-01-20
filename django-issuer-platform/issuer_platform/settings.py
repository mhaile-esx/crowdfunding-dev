"""
Django settings for Issuer Platform project.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Build paths inside the project
BASE_DIR = Path(__file__).resolve().parent.parent

# Security settings
SECRET_KEY = os.getenv('SECRET_KEY', 'django-insecure-change-this-in-production')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1,django,196.188.63.167').split(',')
# Add wildcard support in development
if os.getenv('DEBUG', 'True') == 'True':
    ALLOWED_HOSTS.append('*')

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third-party apps
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'django_filters',
    'drf_yasg',
    'django_celery_beat',
    
    # Core apps
    'issuers.apps.IssuersConfig',
    'blockchain.apps.BlockchainConfig',
    
    # Modular apps (using campaigns_module instead of campaigns to avoid conflicts)
    'campaigns_module.apps.CampaignsModuleConfig',
    'investments.apps.InvestmentsConfig',
    'escrow.apps.EscrowConfig',
    # 'nft.apps.NftConfig',  # Disabled - NFTShareCertificate is in investments
    # DAO Governance
    'dao.apps.DaoConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'issuer_platform.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'issuer_platform.wsgi.application'

# Database - supports both DATABASE_URL and individual DB_* variables
import dj_database_url

DATABASE_URL = os.getenv('DATABASE_URL')
if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.parse(DATABASE_URL)
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.getenv('DB_NAME', 'crowdfundchain_db'),
            'USER': os.getenv('DB_USER', 'dltadmin'),
            'PASSWORD': os.getenv('DB_PASSWORD', 'CrowdfundChain2025!'),
            'HOST': os.getenv('DB_HOST', 'postgres'),
            'PORT': os.getenv('DB_PORT', '5432'),
        }
    }

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Africa/Addis_Ababa'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Custom User Model
AUTH_USER_MODEL = 'issuers.User'

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

# JWT Settings
from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}

# CORS Settings
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5000",
]

# Blockchain Settings
BLOCKCHAIN_SETTINGS = {
    'POLYGON_EDGE_RPC_URL': os.getenv('BLOCKCHAIN_RPC_URL', 'http://localhost:8546'),
    'CHAIN_ID': int(os.getenv('CHAIN_ID', '100')),
    'DEPLOYER_PRIVATE_KEY': os.getenv('BLOCKCHAIN_DEPLOYER_PRIVATE_KEY', ''),
    'DEPLOYER_ADDRESS': os.getenv('BLOCKCHAIN_DEPLOYER_ADDRESS', '0x49065C1C0cFc356313eB67860bD6b697a9317a83'),
    'GAS_LIMIT': int(os.getenv('GAS_LIMIT', '8000000')),
    'GAS_PRICE': int(os.getenv('GAS_PRICE', '1000000000')),  # 1 Gwei
}

# Smart Contract Addresses
SMART_CONTRACTS = {
    'ISSUER_REGISTRY': os.getenv('CONTRACT_ISSUER_REGISTRY', ''),
    'CAMPAIGN_FACTORY': os.getenv('CONTRACT_CAMPAIGN_FACTORY', '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9'),
    'FUND_ESCROW': os.getenv('CONTRACT_FUND_ESCROW', ''),
    'NFT_CERTIFICATE': os.getenv('CONTRACT_NFT_CERTIFICATE', '0x5FbDB2315678afecb367f032d93F642f64180aa3'),
    'DAO_GOVERNANCE': os.getenv('CONTRACT_DAO_GOVERNANCE', '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'),
}

# IPFS Settings
IPFS_SETTINGS = {
    'API_URL': os.getenv('IPFS_API_URL', 'https://ipfs.infura.io:5001'),
    'GATEWAY_URL': os.getenv('IPFS_GATEWAY_URL', 'https://ipfs.io/ipfs/'),
}

# Platform Settings
PLATFORM_SETTINGS = {
    'FEE_PERCENTAGE': float(os.getenv('PLATFORM_FEE_PERCENTAGE', '2.5')),
    'SUCCESS_THRESHOLD': float(os.getenv('SUCCESS_THRESHOLD_PERCENTAGE', '75')),
    'MAX_CAMPAIGN_DURATION': int(os.getenv('MAX_CAMPAIGN_DURATION_DAYS', '180')),
    'MIN_INVESTMENT_AMOUNT': float(os.getenv('MIN_INVESTMENT_AMOUNT', '100')),
}

# Celery Configuration
CELERY_BROKER_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'file': {
            'class': 'logging.FileHandler',
            'filename': BASE_DIR / 'logs' / 'django.log',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
        'blockchain': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}

# Create logs directory
os.makedirs(BASE_DIR / 'logs', exist_ok=True)

# Smart Contract Addresses (Hardhat deployment)
