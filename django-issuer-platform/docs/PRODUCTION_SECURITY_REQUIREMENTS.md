# 🔐 Production Security Requirements

## ⚠️ CRITICAL: Required Security Implementations for Production

This document outlines security features that **MUST** be implemented before deploying to production.

---

## 1. ✅ IMPLEMENTED (Current Status)

### **EIP-191 Signature Verification**
- ✅ Wallet authentication uses `encode_defunct()` for proper personal_sign flow
- ✅ Signature recovery validates wallet ownership
- ✅ Timestamp validation rejects messages older than 5 minutes

### **Role-Based Access Control (RBAC)**
- ✅ All ViewSets enforce role-based filtering via `get_queryset()`
- ✅ No unsafe `queryset` class attributes
- ✅ Admin-only actions protected with `@permission_classes([IsAdminUser])`

### **Input Validation**
- ✅ Serializer-based validation for all endpoints
- ✅ Business rule enforcement (min/max investment, campaign status, etc.)
- ✅ Proper ValidationError handling

---

## 2. ⚠️ REQUIRED FOR PRODUCTION

### **A. Nonce-Based Wallet Authentication** (CRITICAL)

**Current Status:** Timestamp validation provides basic replay protection but is not sufficient.

**Required Implementation:**

#### **Step 1: Create Nonce Model**
```python
# issuers/models.py
from django.db import models
from django.utils import timezone
import secrets

class WalletNonce(models.Model):
    """Server-issued nonces for wallet authentication"""
    wallet_address = models.CharField(max_length=42, db_index=True)
    nonce = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'wallet_nonces'
        indexes = [models.Index(fields=['wallet_address', 'nonce'])]
    
    @classmethod
    def generate_for_wallet(cls, wallet_address):
        """Generate a new nonce for wallet (5 minute TTL)"""
        nonce = secrets.token_urlsafe(32)
        expires_at = timezone.now() + timedelta(minutes=5)
        return cls.objects.create(
            wallet_address=wallet_address.lower(),
            nonce=nonce,
            expires_at=expires_at
        )
    
    def mark_as_used(self):
        """Mark nonce as used (single-use)"""
        self.used = True
        self.save()
    
    @property
    def is_valid(self):
        """Check if nonce is valid (not used and not expired)"""
        return not self.used and timezone.now() < self.expires_at
```

#### **Step 2: Create Nonce Issuance Endpoint**
```python
# issuers/views.py
@api_view(['POST'])
@permission_classes([AllowAny])
def request_wallet_nonce(request):
    """
    Issue a nonce for wallet authentication
    Client must sign this nonce to prove wallet ownership
    """
    wallet_address = request.data.get('wallet_address')
    
    if not wallet_address:
        return Response({'error': 'wallet_address required'}, status=400)
    
    # Check if wallet exists
    user = User.objects.filter(wallet_address__iexact=wallet_address).first()
    if not user:
        return Response({'error': 'Wallet not registered'}, status=404)
    
    # Generate nonce
    nonce_obj = WalletNonce.generate_for_wallet(wallet_address)
    
    return Response({
        'nonce': nonce_obj.nonce,
        'message': f'Login to CrowdfundChain\nNonce: {nonce_obj.nonce}\nExpires at: {nonce_obj.expires_at.isoformat()}',
        'expires_at': nonce_obj.expires_at.isoformat()
    })
```

#### **Step 3: Update Wallet Connect to Validate Nonce**
```python
# issuers/views.py
@api_view(['POST'])
@permission_classes([AllowAny])
def connect_wallet(request):
    """Connect wallet with nonce-based authentication"""
    from web3 import Web3
    from eth_account.messages import encode_defunct
    
    wallet_address = request.data.get('wallet_address')
    signature = request.data.get('signature')
    message = request.data.get('message')
    nonce = request.data.get('nonce')  # NEW: Required nonce
    
    if not all([wallet_address, signature, message, nonce]):
        return Response({'error': 'Missing required fields'}, status=400)
    
    # Validate nonce
    try:
        nonce_obj = WalletNonce.objects.get(
            wallet_address__iexact=wallet_address,
            nonce=nonce
        )
        
        if not nonce_obj.is_valid:
            return Response({
                'error': 'Nonce expired or already used. Request a new nonce.'
            }, status=401)
        
    except WalletNonce.DoesNotExist:
        return Response({'error': 'Invalid nonce'}, status=401)
    
    # Verify signature
    w3 = Web3()
    encoded_message = encode_defunct(text=message)
    recovered_address = w3.eth.account.recover_message(
        encoded_message,
        signature=signature
    )
    
    if recovered_address.lower() != wallet_address.lower():
        return Response({'error': 'Signature verification failed'}, status=401)
    
    # Verify message contains the nonce
    if nonce not in message:
        return Response({'error': 'Message must contain the nonce'}, status=400)
    
    # Mark nonce as used (prevents replay)
    nonce_obj.mark_as_used()
    
    # Authenticate user
    user = User.objects.get(wallet_address__iexact=wallet_address)
    login(request, user)
    
    return Response({
        'message': 'Wallet connected successfully',
        'user': UserSerializer(user).data
    })
```

#### **Step 4: Frontend Implementation**
```javascript
// 1. Request nonce from backend
const { nonce, message } = await fetch('/api/auth/wallet/nonce/', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ wallet_address: walletAddress })
}).then(r => r.json());

// 2. Sign the message containing the nonce
const signature = await window.ethereum.request({
  method: 'personal_sign',
  params: [message, walletAddress]
});

// 3. Connect wallet with signed nonce
const result = await fetch('/api/auth/wallet/connect/', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    wallet_address: walletAddress,
    signature: signature,
    message: message,
    nonce: nonce
  })
}).then(r => r.json());
```

---

### **B. Rate Limiting** (HIGH PRIORITY)

**Required:** Prevent brute-force and DDoS attacks.

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle'
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',      # 100 requests per hour for anonymous users
        'user': '1000/hour',     # 1000 requests per hour for authenticated users
    }
}

# Custom rate limits for sensitive endpoints
class WalletAuthThrottle(throttling.SimpleRateThrottle):
    scope = 'wallet_auth'
    
    def get_cache_key(self, request, view):
        wallet_address = request.data.get('wallet_address', '')
        return f'wallet_auth_{wallet_address.lower()}'

# In settings.py
REST_FRAMEWORK['DEFAULT_THROTTLE_RATES']['wallet_auth'] = '10/hour'
```

---

### **C. HTTPS/SSL Configuration** (CRITICAL)

**Required:** All production traffic must be encrypted.

```python
# settings.py (production)
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
```

**Nginx Configuration:**
```nginx
server {
    listen 443 ssl http2;
    server_name api.crowdfundchain.com;
    
    ssl_certificate /etc/letsencrypt/live/api.crowdfundchain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.crowdfundchain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # ... rest of config
}
```

---

### **D. CORS Configuration** (CRITICAL)

**Required:** Lock down CORS to specific domains.

```python
# settings.py (production)
INSTALLED_APPS += ['corsheaders']

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    # ... other middleware
]

CORS_ALLOWED_ORIGINS = [
    "https://crowdfundchain.com",
    "https://www.crowdfundchain.com",
    "https://app.crowdfundchain.com",
]

CORS_ALLOW_CREDENTIALS = True

# Never use CORS_ALLOW_ALL_ORIGINS = True in production!
```

---

### **E. Database Security** (HIGH PRIORITY)

```python
# settings.py (production)

# Use strong database password
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),  # Strong password from env
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
        'CONN_MAX_AGE': 600,  # Connection pooling
        'OPTIONS': {
            'sslmode': 'require',  # Require SSL for database connections
        }
    }
}
```

---

### **F. Logging & Monitoring** (HIGH PRIORITY)

```python
# settings.py
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
        'file': {
            'level': 'WARNING',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/crowdfundchain/django.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'security_file': {
            'level': 'WARNING',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/crowdfundchain/security.log',
            'maxBytes': 10485760,
            'backupCount': 10,
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'WARNING',
            'propagate': True,
        },
        'django.security': {
            'handlers': ['security_file'],
            'level': 'WARNING',
            'propagate': False,
        },
    },
}

# Integrate with error tracking (e.g., Sentry)
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration

sentry_sdk.init(
    dsn=os.getenv('SENTRY_DSN'),
    integrations=[DjangoIntegration()],
    traces_sample_rate=0.1,
    send_default_pii=False
)
```

---

### **G. Environment Variable Management** (CRITICAL)

**Never commit secrets to git!**

```bash
# Use environment variables for all sensitive data
export SECRET_KEY="your-secret-key-here"
export DATABASE_URL="postgresql://..."
export POLYGON_EDGE_RPC_URL="http://..."
export PRIVATE_KEY="0x..."

# Or use .env file (add to .gitignore!)
pip install python-decouple

# In settings.py
from decouple import config

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
```

---

## 3. 🔍 Security Testing Checklist

Before production deployment:

- [ ] Nonce-based wallet authentication implemented and tested
- [ ] Rate limiting configured for all endpoints
- [ ] HTTPS/SSL certificate installed and verified
- [ ] CORS configured with specific allowed origins only
- [ ] Database SSL connections enabled
- [ ] Error logging and monitoring configured
- [ ] Secret key rotated and stored securely
- [ ] Security headers enabled (HSTS, CSP, X-Frame-Options)
- [ ] SQL injection testing completed
- [ ] XSS vulnerability testing completed
- [ ] CSRF protection verified
- [ ] Penetration testing conducted
- [ ] Dependencies audited for vulnerabilities

---

## 4. 📞 Security Incident Response

In case of security incident:

1. **Immediately** disable affected endpoints
2. Rotate all secrets and API keys
3. Review logs for unauthorized access
4. Notify affected users if data breach occurred
5. Document incident and remediation steps

---

## 5. ✅ Summary

**Current Status:**
- ✅ Signature verification (EIP-191)
- ✅ Timestamp validation (5-minute window)
- ✅ Role-based access control
- ✅ Input validation

**Required for Production:**
- ⚠️ **CRITICAL:** Nonce-based authentication (prevents replay attacks)
- ⚠️ **CRITICAL:** HTTPS/SSL configuration
- ⚠️ **CRITICAL:** CORS lockdown
- ⚠️ **HIGH:** Rate limiting
- ⚠️ **HIGH:** Database security (SSL, strong passwords)
- ⚠️ **HIGH:** Logging & monitoring

**Deployment Readiness:** 60% - Core API functional, critical security features still required.

---

**Last Updated:** November 25, 2025
