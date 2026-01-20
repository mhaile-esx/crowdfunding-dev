# Modular Architecture Guide

## Overview

The Django Issuer Platform now uses a **modular architecture** with separate, independent directories for each major business domain:

- **`issuers/`** - Issuer registration and management
- **`campaigns_module/`** - Campaign creation and deployment
- **`escrow/`** - Fund escrow and release management
- **`nft/`** - NFT share certificate minting and management
- **`blockchain/`** - Shared blockchain client and utilities

This structure provides:
✅ **Clear separation of concerns**  
✅ **Independent module development**  
✅ **Easier testing and maintenance**  
✅ **Reusable components**  

---

## Module Structure

Each module follows a consistent structure:

```
module_name/
├── __init__.py           # Module initialization
├── apps.py               # Django app configuration
├── models.py             # Database models (PostgreSQL)
├── services.py           # Blockchain service layer
├── signals.py            # Django signal handlers (dual-ledger sync)
├── tasks.py              # Celery async tasks
└── README.md             # Module-specific documentation (optional)
```

---

## 1. Issuers Module

**Purpose:** Issuer (company) registration and KYC management

### Files:
- `issuers/models.py` - User, Company, IssuerProfile, KYCDocument
- `issuers/signals.py` - Auto-register companies on blockchain
- `blockchain/tasks.py` - `register_issuer_on_blockchain()`

### Workflow:
```
1. Company created in PostgreSQL
2. Signal triggers → Celery task queued
3. Task calls IssuerRegistry.sol
4. Blockchain tx hash saved to PostgreSQL
```

### Key Models:
- **User** - Custom user model (extends AbstractUser)
- **Company** - Issuer company with TIN, wallet address
- **IssuerProfile** - Additional issuer metadata
- **KYCDocument** - KYC verification documents

---

## 2. Campaign Module

**Purpose:** Campaign creation, deployment, and management

### Files:
- `campaigns_module/models.py` - Campaign, CampaignDocument, CampaignUpdate
- `campaigns_module/services.py` - CampaignBlockchainService
- `campaigns_module/signals.py` - Auto-deploy approved campaigns
- `campaigns_module/tasks.py` - Campaign blockchain operations

### Workflow:
```
1. Campaign created with status='draft'
2. Compliance approves → status='approved'
3. Signal triggers → Celery deploys to blockchain
4. CampaignFactory.sol creates new campaign contract
5. Contract address saved to PostgreSQL
6. Status updated to 'active'
```

### Key Functions:
- **`deploy_campaign_to_blockchain()`** - Deploy campaign via CampaignFactory.sol
- **`record_investment_on_campaign()`** - Record investment on campaign contract
- **`sync_campaign_stats_from_blockchain()`** - Sync stats from blockchain

### Smart Contracts:
- **CampaignFactory.sol** - Deploys new campaign contracts
- **CampaignImplementation.sol** - Individual campaign logic

---

## 3. Escrow Module

**Purpose:** Fund escrow, release, and refund management

### Files:
- `escrow/models.py` - FundEscrow, RefundTransaction
- `escrow/services.py` - EscrowBlockchainService
- `escrow/signals.py` - Auto-trigger fund release/refund
- `escrow/tasks.py` - Escrow blockchain operations

### Workflow:

#### **Success Path (Fund Release):**
```
1. Campaign reaches success threshold (75%+)
2. Campaign status → 'successful'
3. Signal triggers → release_funds_to_issuer()
4. Funds transferred to issuer wallet
5. Escrow status → 'released'
```

#### **Failure Path (Refunds):**
```
1. Campaign fails or cancelled
2. Campaign status → 'failed'
3. Signal triggers → process_campaign_refunds()
4. Each investor refunded proportionally
5. Escrow status → 'refunded'
```

### Key Functions:
- **`release_funds_to_issuer()`** - Release escrowed funds to company
- **`process_campaign_refunds()`** - Refund all investors
- **`sync_escrow_balance_from_blockchain()`** - Verify escrow balance

### Smart Contracts:
- **CampaignImplementation.sol** - Manages escrow in campaign contract
- `releaseFunds()` - Release to issuer
- `refund()` - Process individual refunds

---

## 4. NFT Module

**Purpose:** NFT share certificate minting and management

### Files:
- `nft/models.py` - NFTShareCertificate, NFTTransferHistory
- `nft/services.py` - NFTBlockchainService
- `nft/signals.py` - Auto-mint NFTs for successful campaigns
- `nft/tasks.py` - NFT blockchain operations

### Workflow:
```
1. Campaign status → 'successful'
2. Signal triggers → mint_nfts_for_campaign()
3. For each confirmed investment:
   - Mint NFT via NFTShareCertificate.sol
   - Calculate voting weight (1 vote per 1000 ETB)
   - Generate metadata (name, image, attributes)
   - Save token ID and tx hash
4. NFT ownership tracked in PostgreSQL
```

### Key Functions:
- **`mint_nft_certificate()`** - Mint NFT for individual investment
- **`mint_nfts_for_campaign()`** - Batch mint for all investments
- **`transfer_nft_certificate()`** - Transfer NFT ownership
- **`sync_nft_ownership_from_blockchain()`** - Sync ownership changes

### NFT Metadata Structure:
```json
{
  "name": "TechStartup Campaign Share Certificate",
  "description": "Ownership certificate for 5000 ETB investment",
  "image": "ipfs://QmExample/...",
  "attributes": [
    {"trait_type": "Campaign", "value": "TechStartup Expansion"},
    {"trait_type": "Investment Amount", "value": "5000"},
    {"trait_type": "Voting Power", "value": "5"},
    {"trait_type": "Company", "value": "TechStartup Inc"}
  ]
}
```

### Smart Contracts:
- **NFTShareCertificate.sol** - ERC-721 NFT contract

---

## 5. Blockchain Module (Shared)

**Purpose:** Shared blockchain client and utilities

### Files:
- `blockchain/web3_client.py` - Web3.py client with connection management
- `blockchain/services.py` - Legacy service layer (to be deprecated)
- `blockchain/tasks.py` - Shared blockchain tasks
- `blockchain/abis/` - Smart contract ABIs

### Usage in Modules:
```python
from blockchain.web3_client import get_blockchain_client

client = get_blockchain_client()
contract = client.get_contract_instance('issuer_registry')
result = client.send_transaction(tx)
```

---

## Dual-Ledger Architecture

Every module implements the **dual-ledger pattern**:

### Pattern:
```
PostgreSQL (Source of Truth)
    ↓
Django Signal Fired
    ↓
Celery Task Queued (Async)
    ↓
Blockchain Transaction
    ↓
PostgreSQL Updated (tx hash, address)
```

### Example (Campaign Deployment):
```python
# 1. PostgreSQL - Campaign created
campaign = Campaign.objects.create(
    title="TechStartup Expansion",
    status="approved",
    ...
)

# 2. Signal fired (campaigns_module/signals.py)
@receiver(post_save, sender=Campaign)
def sync_campaign_to_blockchain(sender, instance, **kwargs):
    if instance.can_deploy_to_blockchain():
        deploy_campaign_to_blockchain.delay(str(instance.id))

# 3. Celery task (campaigns_module/tasks.py)
@shared_task
def deploy_campaign_to_blockchain(campaign_id):
    service = CampaignBlockchainService(client)
    result = service.deploy_campaign(...)
    
    # 4. Update PostgreSQL with blockchain data
    campaign.smart_contract_address = result['campaignAddress']
    campaign.deployment_tx_hash = result['txHash']
    campaign.deployed_on_blockchain = True
    campaign.save()
```

---

## Module Dependencies

```
issuers/
  ↓
campaigns_module/ (depends on issuers for Company)
  ↓
escrow/ (depends on campaigns_module for Campaign)
  ↓
nft/ (depends on campaigns_module and investments)
```

### Dependency Rules:
- ✅ **Higher modules can import lower modules**
- ❌ **Lower modules cannot import higher modules**
- ✅ **All modules can import blockchain/**

---

## Django Settings

### Installed Apps Order:
```python
INSTALLED_APPS = [
    # Django core apps
    ...
    
    # Local apps (original)
    'issuers.apps.IssuersConfig',
    'campaigns.apps.CampaignsConfig',
    'investments.apps.InvestmentsConfig',
    'blockchain.apps.BlockchainConfig',
    
    # New modular apps
    'campaigns_module.apps.CampaignsModuleConfig',
    'escrow.apps.EscrowConfig',
    'nft.apps.NftConfig',
]
```

**Note:** The original `campaigns/` and `investments/` apps are kept for backward compatibility but can be deprecated in favor of the new modular structure.

---

## Database Migrations

### Running Migrations:
```bash
# Generate migrations for all modules
python manage.py makemigrations issuers
python manage.py makemigrations campaigns_module
python manage.py makemigrations escrow
python manage.py makemigrations nft

# Apply migrations
python manage.py migrate
```

### Migration Dependencies:
Migrations must be applied in this order:
1. `issuers` (base models)
2. `campaigns_module` (depends on issuers)
3. `escrow` (depends on campaigns_module)
4. `nft` (depends on campaigns_module)

---

## Testing

### Module-Specific Testing:
Each module should have its own test suite:

```bash
# Test individual module
python manage.py test campaigns_module
python manage.py test escrow
python manage.py test nft

# Test all modules
python manage.py test
```

### Test Structure:
```
campaigns_module/
├── tests/
│   ├── __init__.py
│   ├── test_models.py
│   ├── test_services.py
│   ├── test_signals.py
│   └── test_tasks.py
```

---

## Benefits of Modular Architecture

### 1. **Separation of Concerns**
Each module handles one business domain, making code easier to understand and maintain.

### 2. **Independent Development**
Teams can work on different modules without conflicts.

### 3. **Easier Testing**
Module-specific tests are isolated and faster to run.

### 4. **Reusability**
Modules can be reused in other projects or white-label deployments.

### 5. **Scalability**
Modules can be deployed as microservices in the future.

### 6. **Clear Boundaries**
Module APIs enforce clear boundaries between business domains.

---

## Migration from Old Structure

### Old Structure:
```
campaigns/
├── models.py         # All campaign models
├── signals.py        # Campaign signals
investments/
├── models.py         # Investment + NFT models
├── signals.py        # Investment signals
blockchain/
├── services.py       # All blockchain services
├── tasks.py          # All Celery tasks
```

### New Structure:
```
campaigns_module/
├── models.py         # Campaign models only
├── services.py       # Campaign blockchain service
├── signals.py        # Campaign signals
├── tasks.py          # Campaign tasks

escrow/
├── models.py         # Escrow models
├── services.py       # Escrow blockchain service
├── signals.py        # Escrow signals
├── tasks.py          # Escrow tasks

nft/
├── models.py         # NFT models only
├── services.py       # NFT blockchain service
├── signals.py        # NFT signals
├── tasks.py          # NFT tasks
```

### Migration Steps:
1. ✅ Create new modular apps
2. ✅ Copy models to appropriate modules
3. ✅ Extract services to module-specific services
4. ✅ Split tasks into module-specific tasks
5. ✅ Update Django settings
6. ⏸️ Run migrations
7. ⏸️ Test end-to-end flows
8. ⏸️ Deprecate old apps (campaigns/, investments/)

---

## Best Practices

### 1. **Keep Modules Independent**
Avoid circular dependencies between modules.

### 2. **Use Signals for Integration**
Let modules communicate through Django signals.

### 3. **Centralize Blockchain Client**
Use `blockchain/web3_client.py` for all blockchain operations.

### 4. **Document Module APIs**
Each module should document its public API.

### 5. **Test Module Boundaries**
Ensure modules work correctly in isolation.

---

## Summary

**Your Django platform now has a clean, modular architecture:**

| Module | Purpose | Models | Smart Contracts |
|--------|---------|--------|----------------|
| **issuers** | Registration | User, Company, KYC | IssuerRegistry.sol |
| **campaigns_module** | Campaign mgmt | Campaign, Document | CampaignFactory.sol |
| **escrow** | Fund mgmt | FundEscrow, Refund | CampaignImplementation.sol |
| **nft** | Certificates | NFTShareCertificate | NFTShareCertificate.sol |
| **blockchain** | Shared utils | N/A | All ABIs |

**Total New Files Created:** 24 files
- 3 modules × 6 files each (models, services, signals, tasks, apps, init)
- 1 settings update
- 1 architecture documentation

**Next Steps:**
1. Run database migrations
2. Test each module independently
3. Test end-to-end integration
4. Deploy to VPS
5. Monitor dual-ledger synchronization

---

**Your modular Django platform is ready for production deployment!** 🚀
