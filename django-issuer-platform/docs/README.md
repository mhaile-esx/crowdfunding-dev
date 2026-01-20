# Django Issuer Platform for Polygon Edge

Django-based issuer onboarding and campaign management platform integrated with Polygon Edge blockchain.

## Features

- ✅ Issuer registration and verification
- ✅ KYC/Verifiable Credential management
- ✅ Campaign creation and deployment
- ✅ Blockchain integration (Polygon Edge)
- ✅ Fund management and escrow
- ✅ Investment tracking
- ✅ NFT share certificate issuance
- ✅ Role-based access control

## Architecture

```
Django Backend (PostgreSQL)
        ↕
Web3.py Blockchain Service
        ↕
Polygon Edge Network
(IssuerRegistry.sol, CampaignFactory.sol, FundEscrow.sol)
```

## Installation

### 1. Install Dependencies

```bash
cd django-issuer-platform
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings
```

### 3. Setup Database

```bash
python manage.py migrate
python manage.py createsuperuser
```

### 4. Run Development Server

```bash
python manage.py runserver 0.0.0.0:8000
```

## Configuration

### Polygon Edge Settings

Edit `.env`:

```bash
# Blockchain Configuration
POLYGON_EDGE_RPC_URL=http://your-vps-ip:8545
BLOCKCHAIN_DEPLOYER_PRIVATE_KEY=0x...
CHAIN_ID=100

# Smart Contract Addresses
CONTRACT_ISSUER_REGISTRY=0x...
CONTRACT_CAMPAIGN_FACTORY=0x...
CONTRACT_FUND_ESCROW=0x...
CONTRACT_NFT_CERTIFICATE=0x...

# Database
DATABASE_URL=postgresql://user:pass@localhost/issuer_platform
```

## API Endpoints

### Issuer Management

```
POST   /api/issuers/register/          - Register new issuer
GET    /api/issuers/me/                - Get current issuer profile
PUT    /api/issuers/me/                - Update issuer profile
GET    /api/issuers/<id>/status/       - Check issuer blockchain status
```

### Campaign Management

```
POST   /api/campaigns/                 - Create new campaign
GET    /api/campaigns/                 - List all campaigns
GET    /api/campaigns/<id>/            - Get campaign details
POST   /api/campaigns/<id>/deploy/     - Deploy to blockchain
POST   /api/campaigns/<id>/release/    - Release funds (75%+)
POST   /api/campaigns/<id>/refund/     - Process refunds (<75%)
```

### Investment Management

```
POST   /api/investments/               - Record investment
GET    /api/investments/my/            - Get user's investments
POST   /api/investments/<id>/mint-nft/ - Mint NFT certificate
```

## Web Interface

### Issuer Dashboard

```
/issuers/dashboard/                    - Issuer overview
/issuers/register/                     - Registration form
/issuers/kyc/                          - KYC submission
```

### Campaign Management

```
/campaigns/create/                     - Create campaign
/campaigns/<id>/                       - Campaign details
/campaigns/<id>/manage/                - Campaign management
```

## Deployment to VPS

### 1. Copy to VPS

```bash
scp -r django-issuer-platform/ dltadmin@your-vps:/home/dltadmin/
```

### 2. Install on VPS

```bash
ssh dltadmin@your-vps
cd /home/dltadmin/django-issuer-platform
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure for Production

```bash
# Use PostgreSQL
export DATABASE_URL="postgresql://..."

# Set Polygon Edge RPC
export POLYGON_EDGE_RPC_URL="http://localhost:8545"

# Deploy contracts first, then set addresses
export CONTRACT_ISSUER_REGISTRY="0x..."
```

### 4. Run with Gunicorn

```bash
gunicorn issuer_platform.wsgi:application --bind 0.0.0.0:8000
```

## Security

- RBAC with Django permissions
- JWT authentication for API
- Wallet signature verification
- Rate limiting on blockchain operations
- Input validation and sanitization

## Testing

```bash
python manage.py test
```

## License

MIT License
