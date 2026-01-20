# Django Issuer Platform - Quick Start Guide

## 🎉 What You Got

A **complete Django application** for issuer onboarding and campaign management, fully integrated with **Polygon Edge blockchain**.

**Stats:**
- 📝 **2,777 lines of code**
- 🗃️ **11 Django models** (Users, Companies, Campaigns, Investments, NFTs)
- 🔗 **3 Blockchain services** (Issuer, Campaign, NFT)
- 📡 **20+ API endpoints**
- 🏗️ **4 Smart contracts integration** (IssuerRegistry, CampaignFactory, FundEscrow, NFT)

---

## 📁 What's in the Directory

```
django-issuer-platform/
│
├── 📘 Documentation
│   ├── README.md                  ← Project overview
│   ├── QUICK_START.md             ← This file (start here!)
│   ├── DEPLOYMENT_GUIDE.md        ← Full deployment instructions
│   └── INTEGRATION_SUMMARY.md     ← Technical deep dive
│
├── ⚙️ Configuration
│   ├── .env.example               ← Environment variables template
│   ├── requirements.txt           ← Python dependencies
│   ├── manage.py                  ← Django management script
│   └── gunicorn_config.py         ← Production server config
│
├── 🏗️ Django Apps
│   ├── issuer_platform/           ← Main project (settings, URLs)
│   ├── issuers/                   ← Issuer management
│   ├── campaigns/                 ← Campaign management
│   ├── investments/               ← Investment tracking
│   └── blockchain/                ← Blockchain integration (Web3.py)
│
└── 📦 Supporting Files
    ├── templates/                 ← HTML templates
    ├── static/                    ← CSS, JS, images
    ├── media/                     ← Uploaded files
    └── logs/                      ← Application logs
```

---

## 🚀 3-Step Quick Deploy

### **Step 1: Copy to VPS**

```bash
# On ESX, package the project
cd django-issuer-platform
tar -czf ../django-issuer-platform.tar.gz .

# Transfer to VPS
scp django-issuer-platform.tar.gz dltadmin@45.76.159.34:/home/dltadmin/

# On VPS, extract
ssh dltadmin@45.76.159.34
cd /home/dltadmin
tar -xzf django-issuer-platform.tar.gz -C django-issuer-platform/
```

---

### **Step 2: Setup Environment**

```bash
cd /home/dltadmin/django-issuer-platform

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
nano .env  # Edit with your settings
```

**Edit `.env` - Most Important Settings:**

```bash
# Polygon Edge (already running on your VPS)
POLYGON_EDGE_RPC_URL=http://localhost:8545

# Smart contract addresses (deploy contracts first)
CONTRACT_ISSUER_REGISTRY=0x...      # Set after deployment
CONTRACT_CAMPAIGN_FACTORY=0x...     # Set after deployment
CONTRACT_NFT_CERTIFICATE=0x...      # Set after deployment
```

---

### **Step 3: Deploy Smart Contracts**

```bash
# Go to smart contracts directory
cd /home/dltadmin/source/scripts/polygon-edge

# Deploy IssuerRegistry
npx hardhat run scripts/deploy-issuer-registry.js --network polygon-edge
# Copy output address to .env: CONTRACT_ISSUER_REGISTRY=0x...

# Deploy NFTShareCertificate
npx hardhat run scripts/deploy-nft-certificate.js --network polygon-edge
# Copy output address to .env: CONTRACT_NFT_CERTIFICATE=0x...

# Deploy CampaignFactory (depends on NFT address)
npx hardhat run scripts/deploy-campaign-factory.js --network polygon-edge
# Copy output address to .env: CONTRACT_CAMPAIGN_FACTORY=0x...

# Copy ABIs
cd /home/dltadmin/source/scripts/polygon-edge
mkdir -p /home/dltadmin/django-issuer-platform/blockchain/abis

cp smart-contracts/artifacts/contracts/IssuerRegistry.sol/IssuerRegistry.json \
   /home/dltadmin/django-issuer-platform/blockchain/abis/issuer_registry_abi.json
```

---

## 🏃 Run the Application

### **Development Mode:**

```bash
cd /home/dltadmin/django-issuer-platform
source venv/bin/activate

# Setup database
python manage.py migrate
python manage.py createsuperuser

# Run server
python manage.py runserver 0.0.0.0:8000
```

**Access:**
- Web App: `http://45.76.159.34:8000`
- Admin Panel: `http://45.76.159.34:8000/admin`
- API Docs: `http://45.76.159.34:8000/swagger/`

---

### **Production Mode:**

```bash
# Setup systemd service
sudo nano /etc/systemd/system/django-issuer-platform.service
# (Copy content from DEPLOYMENT_GUIDE.md)

# Start service
sudo systemctl enable django-issuer-platform
sudo systemctl start django-issuer-platform
```

---

## 🧪 Test the Integration

### **1. Test Blockchain Connection:**

```bash
cd /home/dltadmin/django-issuer-platform
source venv/bin/activate
python manage.py shell
```

```python
from blockchain.web3_client import get_blockchain_client

# Test connection
client = get_blockchain_client()
print(client.is_connected())  # Should print: True

# Get network info
info = client.get_network_info()
print(info)
# Output: {'connected': True, 'chain_id': 100, 'latest_block': 1234, ...}
```

---

### **2. Test Issuer Registration:**

```bash
curl -X POST http://localhost:8000/api/issuers/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "techstart_ethiopia",
    "email": "admin@techstart.et",
    "password": "SecurePass123!",
    "wallet_address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
    "company_name": "TechStart Ethiopia",
    "tin_number": "1234567890",
    "sector": "technology"
  }'
```

**Expected Response:**
```json
{
  "id": "uuid-123",
  "username": "techstart_ethiopia",
  "company": {
    "id": "uuid-456",
    "name": "TechStart Ethiopia",
    "tin_number": "1234567890",
    "blockchain_address": "0x742d35Cc...",
    "registered_on_blockchain": true
  },
  "token": "eyJ..."
}
```

---

### **3. Test Campaign Creation:**

```bash
# Get JWT token first (from login/register response)
TOKEN="your-jwt-token-here"

curl -X POST http://localhost:8000/api/campaigns/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "TechStart Expansion Fund",
    "description": "Raising capital for expansion into 5 new cities",
    "funding_goal": "500000",
    "duration": 90,
    "sector": "technology"
  }'
```

**Expected Response:**
```json
{
  "id": "uuid-789",
  "title": "TechStart Expansion Fund",
  "funding_goal": "500000.00",
  "current_funding": "0.00",
  "status": "draft",
  "smart_contract_address": "0x...",
  "deployed_on_blockchain": true,
  "deployment_tx_hash": "0x..."
}
```

---

## 📚 Key Features

### **Issuer Management:**
- ✅ User registration with wallet integration
- ✅ Company profile management
- ✅ KYC document upload
- ✅ Blockchain registration (IssuerRegistry.sol)
- ✅ Verifiable Credential (VC) storage

### **Campaign Management:**
- ✅ Campaign creation & deployment
- ✅ Blockchain integration (CampaignFactory.sol)
- ✅ Document upload (IPFS)
- ✅ Fund management (75% threshold)
- ✅ Automated refunds

### **Investment Processing:**
- ✅ MetaMask crypto payments
- ✅ Ethiopian payment gateways (Telebirr, CBE, etc.)
- ✅ Investment tracking
- ✅ NFT certificate minting
- ✅ Voting power calculation

---

## 🔑 Key Endpoints

### Authentication:
```
POST   /api/auth/register/             - Register new user
POST   /api/auth/login/                - Login (get JWT token)
POST   /api/auth/refresh/              - Refresh JWT token
```

### Issuers:
```
POST   /api/issuers/register/          - Register issuer + company
GET    /api/issuers/me/                - Get current issuer profile
POST   /api/issuers/kyc/upload/        - Upload KYC documents
```

### Campaigns:
```
POST   /api/campaigns/                 - Create campaign
GET    /api/campaigns/                 - List all campaigns
POST   /api/campaigns/<id>/deploy/     - Deploy to blockchain
POST   /api/campaigns/<id>/release/    - Release funds (75%+)
POST   /api/campaigns/<id>/refund/     - Process refunds (<75%)
```

### Investments:
```
POST   /api/investments/               - Record investment
POST   /api/investments/<id>/mint-nft/ - Mint NFT certificate
GET    /api/investments/my/            - Get user's investments
```

---

## 🔧 Django Admin Panel

Access at: `http://45.76.159.34:8000/admin`

**Features:**
- Manage users, companies, campaigns
- View investments and payments
- Monitor blockchain transactions
- KYC document approval
- Campaign status updates

**Login with superuser created during setup.**

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────┐
│          Django Issuer Platform             │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │     Web3.py Blockchain Client       │   │
│  │  (blockchain/web3_client.py)        │   │
│  └──────────────┬──────────────────────┘   │
│                 ↓                           │
│  ┌──────────────────────────────────────┐  │
│  │   Blockchain Services                 │  │
│  │  - IssuerBlockchainService            │  │
│  │  - CampaignBlockchainService          │  │
│  │  - NFTCertificateService              │  │
│  └──────────────┬───────────────────────┘  │
│                 ↓                           │
│  ┌──────────────────────────────────────┐  │
│  │   Django Models (PostgreSQL)          │  │
│  │  - User, Company, IssuerProfile       │  │
│  │  - Campaign, Investment               │  │
│  │  - NFTShareCertificate, Payment       │  │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
                 ↕
┌─────────────────────────────────────────────┐
│     Polygon Edge Blockchain (VPS)           │
│                                             │
│  Node 1 (RPC): http://localhost:8545       │
│                                             │
│  Smart Contracts:                           │
│  - IssuerRegistry.sol                       │
│  - CampaignFactory.sol                      │
│  - CampaignImplementation.sol               │
│  - NFTShareCertificate.sol                  │
│  - FundEscrow.sol                           │
└─────────────────────────────────────────────┘
```

---

## 🆘 Troubleshooting

### **Cannot connect to Polygon Edge:**

```bash
# Test RPC connection
curl http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Should return: {"jsonrpc":"2.0","id":1,"result":"0x4d2"}
```

### **Smart contract calls fail:**

```bash
# Verify contract addresses in .env
cat .env | grep CONTRACT_

# Test in Django shell
python manage.py shell
>>> from blockchain.services import IssuerBlockchainService
>>> service = IssuerBlockchainService()
>>> service.client.is_connected()
True
```

### **Database errors:**

```bash
# Check database connection
python manage.py check --database default

# View migrations
python manage.py showmigrations

# Apply migrations
python manage.py migrate
```

---

## 📖 Documentation Files

1. **README.md** - Project overview
2. **QUICK_START.md** (this file) - Get started fast
3. **DEPLOYMENT_GUIDE.md** - Complete deployment steps
4. **INTEGRATION_SUMMARY.md** - Technical architecture
5. **ISSUER_SYSTEM_FILES.md** - File-by-file breakdown (from original Node.js version)

---

## 🎯 Next Steps

After basic deployment:

1. **Configure SSL/TLS** with Let's Encrypt
2. **Setup Celery** for background blockchain tasks
3. **Add monitoring** (Prometheus + Grafana)
4. **Configure backups** for database
5. **Setup CI/CD** pipeline
6. **Load test** the application
7. **Security audit** before production

---

## 💡 Pro Tips

1. **Use Django Admin** for easy data management
2. **Check logs** regularly: `tail -f logs/django.log`
3. **Test locally** before deploying to production
4. **Keep ABIs updated** when contracts change
5. **Monitor gas prices** for blockchain operations
6. **Backup database** before migrations
7. **Use environment variables** for all secrets

---

## 📞 Getting Help

- **Logs**: Check `/home/dltadmin/django-issuer-platform/logs/`
- **Django Shell**: `python manage.py shell` for debugging
- **Blockchain Status**: `curl http://localhost:8000/api/blockchain/network-info/`
- **Database**: `python manage.py dbshell` for SQL console

---

**Your Django Issuer Platform is ready!** 🚀

Start with development mode, test thoroughly, then deploy to production.

All smart contracts from your ESX workspace can be deployed to Polygon Edge on your VPS.

**Happy deploying!**
