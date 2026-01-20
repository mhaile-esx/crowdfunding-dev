# Django Issuer Platform - Deployment Guide

## Complete Deployment to VPS with Polygon Edge

This guide shows how to deploy the Django Issuer Platform on your VPS alongside the running Polygon Edge network.

---

## Prerequisites

✅ VPS with Polygon Edge network running (Node 1 RPC: port 8545)
✅ Python 3.9+ installed
✅ PostgreSQL 14+ installed
✅ Smart contracts deployed to Polygon Edge

---

## Step 1: Copy Django Project to VPS

### On Your Local Machine (ESX):

```bash
# Package the Django project
cd django-issuer-platform
tar -czf django-issuer-platform.tar.gz .

# Transfer to VPS
scp django-issuer-platform.tar.gz dltadmin@45.76.159.34:/home/dltadmin/
```

### On VPS:

```bash
# Extract
cd /home/dltadmin
tar -xzf django-issuer-platform.tar.gz -C /home/dltadmin/django-issuer-platform/
cd /home/dltadmin/django-issuer-platform
```

---

## Step 2: Setup Python Environment

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

---

## Step 3: Configure Environment Variables

```bash
# Create .env file
cp .env.example .env
nano .env
```

### Update `.env`:

```bash
# Django
SECRET_KEY=your-production-secret-key-here
DEBUG=False
ALLOWED_HOSTS=45.76.159.34,localhost,127.0.0.1

# Database
DB_NAME=issuer_platform
DB_USER=postgres
DB_PASSWORD=your-db-password
DB_HOST=localhost
DB_PORT=5432

# Blockchain - Polygon Edge (local VPS)
POLYGON_EDGE_RPC_URL=http://localhost:8545
BLOCKCHAIN_DEPLOYER_PRIVATE_KEY=0x4b65ca150fa9554def89d89d2473a2e8ce5c28c75f6816a27e10a3d84bd2a33c
BLOCKCHAIN_DEPLOYER_ADDRESS=0x49065C1C0cFc356313eB67860bD6b697a9317a83
CHAIN_ID=100

# Smart Contracts (set after deployment)
CONTRACT_ISSUER_REGISTRY=0x...
CONTRACT_CAMPAIGN_FACTORY=0x...
CONTRACT_FUND_ESCROW=0x...
CONTRACT_NFT_CERTIFICATE=0x...
```

---

## Step 4: Setup PostgreSQL Database

```bash
# Create database
sudo -u postgres createdb issuer_platform

# Create user (if needed)
sudo -u postgres psql -c "CREATE USER issuer_platform_user WITH PASSWORD 'your-password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE issuer_platform TO issuer_platform_user;"
```

---

## Step 5: Deploy Smart Contracts

### Copy smart contracts to deployment location:

```bash
# From ESX, copy the 4 main smart contracts
cd /home/dltadmin/source/scripts/polygon-edge/smart-contracts/contracts

# Ensure you have:
# - IssuerRegistry.sol
# - CampaignFactory.sol
# - CampaignImplementation.sol  
# - FundEscrow.sol
# - NFTShareCertificate.sol
```

### Deploy contracts:

```bash
cd /home/dltadmin/source/scripts/polygon-edge

# Compile contracts
npx hardhat compile

# Deploy IssuerRegistry
npx hardhat run scripts/deploy-issuer-registry.js --network polygon-edge
# Output: IssuerRegistry deployed to: 0xABC...
# Copy this address to .env CONTRACT_ISSUER_REGISTRY

# Deploy NFTShareCertificate
npx hardhat run scripts/deploy-nft-certificate.js --network polygon-edge
# Output: NFTShareCertificate deployed to: 0xDEF...
# Copy to .env CONTRACT_NFT_CERTIFICATE

# Deploy CampaignFactory
npx hardhat run scripts/deploy-campaign-factory.js --network polygon-edge
# Output: CampaignFactory deployed to: 0xGHI...
# Copy to .env CONTRACT_CAMPAIGN_FACTORY

# Deploy FundEscrow
npx hardhat run scripts/deploy-fund-escrow.js --network polygon-edge
# Output: FundEscrow deployed to: 0xJKL...
# Copy to .env CONTRACT_FUND_ESCROW
```

### Update Django `.env` with contract addresses:

```bash
cd /home/dltadmin/django-issuer-platform
nano .env

# Add the deployed addresses:
CONTRACT_ISSUER_REGISTRY=0xABC...
CONTRACT_CAMPAIGN_FACTORY=0xGHI...
CONTRACT_FUND_ESCROW=0xJKL...
CONTRACT_NFT_CERTIFICATE=0xDEF...
```

---

## Step 6: Copy Smart Contract ABIs

Smart contract ABIs are needed for Web3.py to interact with contracts.

```bash
# Create ABI directory
mkdir -p /home/dltadmin/django-issuer-platform/blockchain/abis

# Copy ABIs from compiled contracts
cd /home/dltadmin/source/scripts/polygon-edge

# Extract ABIs and save to Django project
cp smart-contracts/artifacts/contracts/IssuerRegistry.sol/IssuerRegistry.json \
   /home/dltadmin/django-issuer-platform/blockchain/abis/issuer_registry_abi.json

cp smart-contracts/artifacts/contracts/CampaignFactory.sol/CampaignFactory.json \
   /home/dltadmin/django-issuer-platform/blockchain/abis/campaign_factory_abi.json

cp smart-contracts/artifacts/contracts/NFTShareCertificate.sol/NFTShareCertificate.json \
   /home/dltadmin/django-issuer-platform/blockchain/abis/nft_certificate_abi.json

cp smart-contracts/artifacts/contracts/FundEscrow.sol/FundEscrow.json \
   /home/dltadmin/django-issuer-platform/blockchain/abis/fund_escrow_abi.json
```

---

## Step 7: Run Django Migrations

```bash
cd /home/dltadmin/django-issuer-platform
source venv/bin/activate

# Make migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser
# Username: admin
# Email: admin@crowdfundchain.com
# Password: [secure password]
```

---

## Step 8: Collect Static Files

```bash
python manage.py collectstatic --noinput
```

---

## Step 9: Test the Application

### Development Server Test:

```bash
# Run development server
python manage.py runserver 0.0.0.0:8000

# Test connection
curl http://localhost:8000/api/blockchain/health

# Check blockchain connection
curl http://localhost:8000/api/blockchain/network-info
```

Expected output:
```json
{
  "connected": true,
  "chain_id": 100,
  "latest_block": 1234,
  "deployer_balance": "1000000000000000000000"
}
```

---

## Step 10: Setup Gunicorn for Production

### Create Gunicorn configuration:

```bash
nano /home/dltadmin/django-issuer-platform/gunicorn_config.py
```

```python
import multiprocessing

bind = "0.0.0.0:8000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 50
timeout = 120
keepalive = 5
errorlog = "/home/dltadmin/django-issuer-platform/logs/gunicorn-error.log"
accesslog = "/home/dltadmin/django-issuer-platform/logs/gunicorn-access.log"
loglevel = "info"
```

### Create logs directory:

```bash
mkdir -p /home/dltadmin/django-issuer-platform/logs
```

### Run Gunicorn:

```bash
gunicorn issuer_platform.wsgi:application -c gunicorn_config.py
```

---

## Step 11: Setup Systemd Service

### Create systemd service file:

```bash
sudo nano /etc/systemd/system/django-issuer-platform.service
```

```ini
[Unit]
Description=Django Issuer Platform
After=network.target postgresql.service

[Service]
Type=notify
User=dltadmin
Group=dltadmin
WorkingDirectory=/home/dltadmin/django-issuer-platform
Environment="PATH=/home/dltadmin/django-issuer-platform/venv/bin"
ExecStart=/home/dltadmin/django-issuer-platform/venv/bin/gunicorn \
    issuer_platform.wsgi:application \
    -c /home/dltadmin/django-issuer-platform/gunicorn_config.py
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Enable and start service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable django-issuer-platform
sudo systemctl start django-issuer-platform

# Check status
sudo systemctl status django-issuer-platform

# View logs
sudo journalctl -u django-issuer-platform -f
```

---

## Step 12: Setup Nginx Reverse Proxy

### Install Nginx (if not already installed):

```bash
sudo apt install nginx -y
```

### Create Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/issuer-platform
```

```nginx
upstream django_app {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name 45.76.159.34;

    client_max_body_size 20M;

    location /static/ {
        alias /home/dltadmin/django-issuer-platform/staticfiles/;
    }

    location /media/ {
        alias /home/dltadmin/django-issuer-platform/media/;
    }

    location / {
        proxy_pass http://django_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}
```

### Enable site and restart Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/issuer-platform /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## Step 13: Test Complete Integration

### Test API Endpoints:

```bash
# Health check
curl http://45.76.159.34/api/blockchain/health

# Network info
curl http://45.76.159.34/api/blockchain/network-info

# Test issuer registration (requires JWT token)
curl -X POST http://45.76.159.34/api/issuers/register/ \
  -H "Authorization: Bearer <your-jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "company_name": "TechStart Ethiopia",
    "tin_number": "1234567890",
    "sector": "technology",
    "wallet_address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
  }'
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    VPS Server                        │
│  ┌──────────────────────────────────────────────┐   │
│  │         Polygon Edge Network                  │   │
│  │  Node 1 (RPC):  http://localhost:8545       │   │
│  │  Nodes 2-4:     Internal network             │   │
│  └──────────────────────────────────────────────┘   │
│                         ↕                            │
│  ┌──────────────────────────────────────────────┐   │
│  │    Django Issuer Platform (Port 8000)        │   │
│  │                                               │   │
│  │  ┌────────────────────────────────────────┐  │   │
│  │  │  Web3.py Client                        │  │   │
│  │  │  - IssuerBlockchainService             │  │   │
│  │  │  - CampaignBlockchainService           │  │   │
│  │  │  - NFTCertificateService               │  │   │
│  │  └────────────────────────────────────────┘  │   │
│  │                                               │   │
│  │  ┌────────────────────────────────────────┐  │   │
│  │  │  Django ORM (PostgreSQL)               │  │   │
│  │  │  - Users, Companies, Campaigns         │  │   │
│  │  │  - Investments, NFTs, Payments         │  │   │
│  │  └────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────┘   │
│                         ↕                            │
│  ┌──────────────────────────────────────────────┐   │
│  │         Nginx Reverse Proxy                   │   │
│  │         Port 80 → Django Port 8000           │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                         ↕
              External Users/Clients
```

---

## Maintenance Commands

### View application logs:

```bash
# Django logs
tail -f /home/dltadmin/django-issuer-platform/logs/django.log

# Gunicorn logs
tail -f /home/dltadmin/django-issuer-platform/logs/gunicorn-error.log

# Systemd logs
sudo journalctl -u django-issuer-platform -f
```

### Restart services:

```bash
# Restart Django app
sudo systemctl restart django-issuer-platform

# Restart Nginx
sudo systemctl restart nginx
```

### Run management commands:

```bash
cd /home/dltadmin/django-issuer-platform
source venv/bin/activate

# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Django shell
python manage.py shell
```

---

## Troubleshooting

### Cannot connect to Polygon Edge:

```bash
# Check if Node 1 is running
curl http://localhost:8545

# Check Polygon Edge logs
cd /home/dltadmin/source/scripts/polygon-edge/polygon-network
docker-compose logs -f bor-0
```

### Database connection errors:

```bash
# Test PostgreSQL connection
psql -U postgres -d issuer_platform -c "SELECT 1;"

# Check Django database config
python manage.py check --database default
```

### Smart contract interaction fails:

```bash
# Verify contract addresses in .env
cat .env | grep CONTRACT_

# Test blockchain connection
python manage.py shell
>>> from blockchain.web3_client import get_blockchain_client
>>> client = get_blockchain_client()
>>> client.is_connected()
True
```

---

## Security Checklist

- [ ] Changed `SECRET_KEY` in production
- [ ] Set `DEBUG=False`
- [ ] Configured `ALLOWED_HOSTS` correctly
- [ ] Database password is strong and secure
- [ ] Private keys are stored securely in `.env`
- [ ] File permissions are correct (`chmod 600 .env`)
- [ ] Nginx is configured with proper headers
- [ ] Regular backups are scheduled

---

## Next Steps

1. **Configure SSL/TLS** with Let's Encrypt for HTTPS
2. **Setup Celery** for background blockchain tasks
3. **Configure monitoring** with Prometheus/Grafana
4. **Implement logging** aggregation (ELK stack)
5. **Setup backup** procedures for database and blockchain
6. **Configure firewall** rules for security

---

## Support

For issues or questions, refer to:
- `README.md` - Project overview
- `ISSUER_SYSTEM_FILES.md` - Component documentation
- Django logs: `/home/dltadmin/django-issuer-platform/logs/`

---

**Deployment Complete!** 🚀

Your Django Issuer Platform is now running alongside Polygon Edge blockchain.

Access the platform at: `http://45.76.159.34`
API Documentation: `http://45.76.159.34/swagger/`
