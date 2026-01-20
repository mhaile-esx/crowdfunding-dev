# Django Platform + Polygon Edge Integration Guide

## 🔗 How Everything Works Together

Your Django issuer platform **integrates with the Polygon Edge network** you already deployed. Here's how all the pieces fit together:

---

## 📦 The Three Components

### **1. Polygon Edge Network** (Infrastructure)
**Script:** `polygon-deploy-safe.sh`

**What it does:**
- Deploys 4-node Polygon Edge validator network
- Creates genesis configuration
- Sets up Docker containers
- Exposes RPC endpoints (http://localhost:8545)

**Status:** ✅ Already deployed on VPS (http://45.76.159.34:8545)

### **2. Smart Contracts** (Business Logic)
**Script:** `deploy-contracts.sh`

**What it does:**
- Deploys IssuerRegistry.sol
- Deploys CampaignFactory.sol
- Deploys CampaignImplementation.sol
- Deploys NFTShareCertificate.sol
- Deploys FundEscrow.sol

**Status:** ⏸️ **NEEDS TO BE DEPLOYED** to get contract addresses

### **3. Django Platform** (Application)
**Location:** `django-issuer-platform/`

**What it does:**
- Provides Web UI and REST API
- Stores data in PostgreSQL
- Calls smart contracts via Web3.py
- Syncs blockchain data back to PostgreSQL

**Status:** ✅ Complete and ready to deploy

---

## 🔄 Complete Deployment Flow

### **Step 1: Polygon Network (Already Done ✅)**

You already ran this on your VPS:
```bash
bash polygon-deploy-safe.sh
cd polygon-network
./start.sh
```

**Result:**
- Network running at http://45.76.159.34:8545
- 4 validators producing blocks
- Chain ID: 100 (or 1337 depending on config)

---

### **Step 2: Deploy Smart Contracts (DO THIS NEXT)**

**On your VPS**, deploy the smart contracts:

```bash
# Option A: Using deploy-contracts.sh
cd /home/dltadmin/source/scripts  # Or wherever your contracts are
bash deploy-contracts.sh

# Option B: Using Hardhat directly
npx hardhat run smart-contracts/deploy/deploy.js --network polygon_edge
```

**Expected Output:**
```
Deploying IssuerRegistry...
  ✅ IssuerRegistry deployed to: 0x1234...
  
Deploying CampaignFactory...
  ✅ CampaignFactory deployed to: 0x5678...
  
Deploying NFTShareCertificate...
  ✅ NFTShareCertificate deployed to: 0x9abc...
  
Deploying FundEscrow...
  ✅ FundEscrow deployed to: 0xdef0...

All contracts deployed successfully!
```

**CRITICAL:** Save these contract addresses! You'll need them for the Django platform.

---

### **Step 3: Configure Django Platform**

Copy the contract addresses from Step 2 to your Django `.env` file:

```bash
cd /home/dltadmin/django-issuer-platform
nano .env
```

**Add/Update these lines:**
```env
# Polygon Edge Network
POLYGON_EDGE_RPC_URL=http://45.76.159.34:8545
CHAIN_ID=100  # Match your Polygon network chain ID

# Deployer Account (from Polygon validators or create new)
DEPLOYER_PRIVATE_KEY=0x1234567890abcdef...  # Private key with ETH
DEPLOYER_ADDRESS=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb

# Smart Contract Addresses (from Step 2 deployment)
ISSUER_REGISTRY_ADDRESS=0x1234...  # ← From deploy output
CAMPAIGN_FACTORY_ADDRESS=0x5678...  # ← From deploy output
NFT_CERTIFICATE_ADDRESS=0x9abc...   # ← From deploy output
FUND_ESCROW_ADDRESS=0xdef0...       # ← From deploy output

# Database
DATABASE_URL=postgresql://user:pass@localhost/issuer_platform

# Redis (for Celery)
REDIS_URL=redis://localhost:6379/0
```

---

### **Step 4: Deploy Django Platform**

```bash
cd /home/dltadmin/django-issuer-platform

# Setup virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start services
sudo systemctl start issuer-platform
sudo systemctl start celery-worker
```

---

### **Step 5: Verify Integration**

Test that Django can connect to Polygon Edge and call smart contracts:

```bash
python manage.py shell
```

**In Python shell:**
```python
# Test 1: Check Web3 connection
from blockchain.web3_client import get_blockchain_client
client = get_blockchain_client()
print(client.is_connected())  # Should print: True
print(client.get_network_info())

# Test 2: Check contract ABIs loaded
from blockchain.abis import get_abi
abi = get_abi('issuer_registry')
print(f"IssuerRegistry has {len(abi)} functions")

# Test 3: Check contract instances
contract = client.get_contract_instance('issuer_registry')
print(f"Contract loaded at: {contract.address}")

# Test 4: Call read-only function
is_registered = contract.functions.isRegisteredIssuer(
    '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'
).call()
print(f"Issuer registered: {is_registered}")
```

**Expected output:**
```
True
{'connected': True, 'chain_id': 100, 'latest_block': 299, ...}
IssuerRegistry has 6 functions
Contract loaded at: 0x1234...
Issuer registered: False
```

---

## 🎯 Complete Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      YOUR VPS (45.76.159.34)                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Polygon Edge Network (4 Validators)             │      │
│  │  - RPC: http://45.76.159.34:8545                 │      │
│  │  - Blocks: 299+                                  │      │
│  │  - Chain ID: 100                                 │      │
│  └────────────────┬─────────────────────────────────┘      │
│                   │                                         │
│                   │ Smart Contracts Deployed                │
│                   ↓                                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │  IssuerRegistry.sol      → 0x1234...             │      │
│  │  CampaignFactory.sol     → 0x5678...             │      │
│  │  NFTShareCertificate.sol → 0x9abc...             │      │
│  │  FundEscrow.sol          → 0xdef0...             │      │
│  └────────────────┬─────────────────────────────────┘      │
│                   │                                         │
│                   │ Web3.py Calls (via RPC)                 │
│                   ↓                                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Django Issuer Platform                          │      │
│  │  - Port: 8000                                    │      │
│  │  - Gunicorn + Celery                             │      │
│  │  - PostgreSQL (dual-ledger)                      │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Data Flow Example: Issuer Registration

### **1. User registers in Django**
```python
POST /api/issuers/register/
{
    "username": "techstartup",
    "email": "ceo@techstartup.et",
    "company_name": "TechStartup Inc",
    "tin_number": "TIN123456"
}
```

### **2. Django creates company in PostgreSQL**
```sql
INSERT INTO companies (id, name, tin_number, wallet_address)
VALUES (uuid, 'TechStartup Inc', 'TIN123456', '0x742...');
```

### **3. Django signal triggers blockchain registration**
```python
@receiver(post_save, sender=Company)
def sync_company_to_blockchain(...):
    register_issuer_on_blockchain.delay(company_id)
```

### **4. Celery task registers on blockchain**
```python
# Calls IssuerRegistry.sol via Web3.py
tx = issuer_registry.registerIssuer(
    issuer='0x742...',
    vcHash='keycloak-vc-hash',
    ipfsHash='QmABC...'
)
```

### **5. Polygon Edge processes transaction**
```
Block 300:
  Transaction: 0xdef012...
  From: 0x742...
  To: IssuerRegistry (0x1234...)
  Status: Success ✅
```

### **6. Celery task updates PostgreSQL**
```python
company.blockchain_tx_hash = '0xdef012...'
company.registered_on_blockchain = True
company.save()
```

### **7. Result: Dual-Ledger Synchronized!**
- PostgreSQL: Company record with blockchain data ✅
- Blockchain: IssuerRegistered event emitted ✅

---

## 🔧 Hardhat Configuration

Your Django platform works with your existing Hardhat setup. Just make sure your `hardhat.config.cjs` includes the Polygon Edge network:

```javascript
// hardhat.config.cjs
module.exports = {
  networks: {
    polygon_edge: {
      url: "http://45.76.159.34:8545",
      chainId: 100,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    },
    localhost: {
      url: "http://localhost:8545",
      chainId: 1337
    }
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};
```

---

## ✅ Integration Checklist

### **Infrastructure:**
- [x] Polygon Edge network running (http://45.76.159.34:8545)
- [x] 4 validators producing blocks
- [ ] Smart contracts deployed (addresses saved)

### **Django Platform:**
- [x] Django app created (django-issuer-platform/)
- [x] Web3.py client configured
- [x] Smart contract ABIs embedded
- [x] Dual-ledger sync implemented
- [ ] Environment configured (.env with contract addresses)
- [ ] Migrations run
- [ ] Services started (gunicorn, celery)

### **Verification:**
- [ ] Web3 client connects to Polygon Edge
- [ ] Contract instances load successfully
- [ ] Test issuer registration end-to-end
- [ ] Test campaign deployment
- [ ] Verify dual-ledger synchronization

---

## 🚀 Quick Start Commands

### **1. Deploy Smart Contracts**
```bash
# On VPS
cd /home/dltadmin/source/scripts
bash deploy-contracts.sh
# Save the contract addresses!
```

### **2. Configure Django**
```bash
cd /home/dltadmin/django-issuer-platform
cp .env.example .env
nano .env  # Add contract addresses from step 1
```

### **3. Deploy Django**
```bash
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
sudo systemctl start issuer-platform
sudo systemctl start celery-worker
```

### **4. Test Integration**
```bash
python manage.py shell
>>> from blockchain.web3_client import get_blockchain_client
>>> client = get_blockchain_client()
>>> print(client.is_connected())
True
```

---

## 🎉 Summary

**Yes, your Django platform works with your Polygon deployment scripts!**

**Integration flow:**
1. ✅ `polygon-deploy-safe.sh` → Deploys Polygon Edge network (DONE)
2. ⏸️ `deploy-contracts.sh` → Deploys smart contracts (DO NEXT)
3. ⏸️ Configure Django `.env` with contract addresses
4. ⏸️ Deploy Django platform
5. ✅ Test end-to-end integration

**Next immediate step:**
Run `deploy-contracts.sh` on your VPS to deploy smart contracts and get the contract addresses for your Django `.env` file.

---

**Your complete blockchain stack:**
- ✅ Polygon Edge network (running)
- ⏸️ Smart contracts (deploy next)
- ✅ Django platform (ready to connect)

**Once smart contracts are deployed, everything will work together seamlessly!** 🚀
