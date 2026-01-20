# CrowdfundChain VPS Deployment Guide

This guide documents the complete process for deploying CrowdfundChain on an Ubuntu VPS with a private Polygon Edge blockchain network.

## Prerequisites

- Ubuntu 20.04+ VPS with at least 4GB RAM
- Docker and Docker Compose installed
- Node.js 18+ installed
- Git access to the repository

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url> /home/dltadmin/crowdfunding
cd /home/dltadmin/crowdfunding

# 2. Copy environment file
cp .env.example .env
# Edit .env with your configuration

# 3. Setup Polygon Edge network
./scripts/vps-setup-polygon-edge.sh

# 4. Start blockchain nodes
docker-compose up -d polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4

# 5. Wait for consensus and deploy contracts
sleep 30
./scripts/vps-deploy-contracts.sh

# 6. Start remaining services
docker-compose up -d
```

## Detailed Deployment Steps

### Step 1: Environment Setup

Create the `.env` file with these key configurations:

```bash
# Blockchain
CHAIN_ID=100
POLYGON_EDGE_PRIVATE_KEY=0x<your-deployer-private-key>
DEPLOYER_ADDRESS=0x<your-deployer-address>

# Database
POSTGRES_DB=crowdfundchain_db
POSTGRES_USER=dltadmin
POSTGRES_PASSWORD=<secure-password>

# Django
DJANGO_SECRET_KEY=<random-string>
ALLOWED_HOSTS=your-domain.com,your-ip
```

### Step 2: Initialize Polygon Edge Network

The setup script creates:
- 4 validator nodes with BLS keys
- Genesis block with IBFT consensus
- Pre-funded accounts for validators and deployer

```bash
./scripts/vps-setup-polygon-edge.sh
```

**What it does:**
1. Creates directory structure for 4 nodes
2. Generates validator keys (ECDSA + BLS)
3. Extracts public keys and node IDs
4. Generates genesis.json with proper BLS validators
5. Premines 1M ETH to each validator and deployer

**Output files:**
- `polygon-edge/genesis.json` - Genesis block configuration
- `polygon-edge/node-X/address.txt` - Validator addresses
- `polygon-edge/node-X/bls-public.txt` - BLS public keys
- `polygon-edge/node-X/node-id.txt` - LibP2P node IDs
- `polygon-edge/network-config.txt` - Summary of network config

### Step 3: Start Blockchain Nodes

```bash
docker-compose up -d polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4
```

Wait 20-30 seconds for IBFT consensus to start producing blocks:

```bash
# Check block number (should be > 0)
curl -s http://localhost:8545 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Step 4: Deploy Smart Contracts

```bash
export POLYGON_EDGE_PRIVATE_KEY=0x<your-deployer-private-key>
./scripts/vps-deploy-contracts.sh
```

**Deployed Contracts:**
- `NFTShareCertificate` - ERC721 for investment certificates
- `DAOGovernance` - Governance and voting
- `CampaignFactory` - Creates campaign contracts
- `CampaignImplementation` - Campaign logic template

Contract addresses are saved to `deployment-info.json` and appended to `.env`.

### Step 5: Start Application Services

```bash
docker-compose up -d
```

This starts:
- PostgreSQL database
- Redis (for Celery)
- Django API server
- Celery workers
- Nginx reverse proxy

## Troubleshooting

### Blockchain Not Producing Blocks

If block number stays at 0:

1. **Check node logs:**
   ```bash
   docker logs polygon-edge-node1 --tail 50
   ```

2. **Verify genesis has validators:**
   ```bash
   cat polygon-edge/genesis.json | grep extraData
   # Should have a long hex string with validator data
   ```

3. **Reset blockchain:**
   ```bash
   ./scripts/vps-reset-blockchain.sh
   ```

### "Public key must be 48 bytes" Error

This means BLS keys are wrong. The genesis needs 96-character hex BLS public keys (48 bytes):

```bash
# Get correct BLS keys
docker exec polygon-edge-node1 polygon-edge secrets output --data-dir /data/node1 | grep "BLS Public key"
```

Then regenerate genesis with `./scripts/vps-reset-blockchain.sh`.

### "Replacement tx underpriced" or "Already known"

Transaction is stuck in mempool. Use higher gas price or higher nonce:

```bash
# Check pending nonce
curl -s http://localhost:8545 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["0xYOUR_ADDRESS","pending"],"id":1}'
```

### Contract Deployment Fails - "Insufficient funds"

Deployer account not premined. Either:
1. Re-run `./scripts/vps-reset-blockchain.sh` (resets everything)
2. Transfer from a validator account:

```bash
node -e "
const {ethers} = require('ethers');
const p = new ethers.JsonRpcProvider('http://localhost:8545');
const wallet = new ethers.Wallet('0xVALIDATOR_PRIVATE_KEY', p);
wallet.sendTransaction({
  to: '0xDEPLOYER_ADDRESS',
  value: ethers.parseEther('10000'),
  gasLimit: 21000,
  gasPrice: ethers.parseUnits('1', 'gwei'),
  type: 0
}).then(tx => tx.wait()).then(console.log);
"
```

## Network Configuration

| Parameter | Value |
|-----------|-------|
| Chain ID | 100 |
| RPC URL | http://localhost:8545 |
| WebSocket | ws://localhost:8545 |
| Block Time | ~2 seconds |
| Block Gas Limit | 10,000,000 |
| Consensus | IBFT with BLS |
| Validators | 4 nodes |

## Security Notes

1. **Private Keys**: Never commit private keys. Use `.env` file (gitignored).
2. **Validator Keys**: Stored in `polygon-edge/node-X/consensus/`. Back these up!
3. **Genesis**: Contains pre-funded addresses. Regenerate for production.
4. **Firewall**: Only expose ports 80/443 (Nginx). Block 8545 externally.

## File Structure

```
/home/dltadmin/crowdfunding/
├── .env                          # Environment configuration
├── docker-compose.yml            # Docker services
├── polygon-edge/
│   ├── genesis.json              # Blockchain genesis
│   ├── network-config.txt        # Network summary
│   ├── node-1/
│   │   ├── address.txt           # Validator address
│   │   ├── bls-public.txt        # BLS public key
│   │   ├── node-id.txt           # LibP2P node ID
│   │   └── consensus/
│   │       ├── validator.key     # ECDSA private key
│   │       └── validator-bls.key # BLS private key
│   └── node-2/, node-3/, node-4/ # Same structure
├── smart-contracts/
│   └── deploy/
│       └── deploy.cjs            # Deployment script
├── deployment-info.json          # Deployed contract addresses
└── scripts/
    ├── vps-setup-polygon-edge.sh # Initial setup
    ├── vps-deploy-contracts.sh   # Deploy contracts
    └── vps-reset-blockchain.sh   # Reset blockchain
```

## Maintenance

### Backup Validator Keys
```bash
tar -czf validator-keys-backup.tar.gz \
    polygon-edge/node-1/consensus \
    polygon-edge/node-2/consensus \
    polygon-edge/node-3/consensus \
    polygon-edge/node-4/consensus
```

### View Node Logs
```bash
docker logs polygon-edge-node1 -f
```

### Check Blockchain Status
```bash
# Block number
curl -s http://localhost:8545 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Peers
docker exec polygon-edge-node1 polygon-edge peers list --grpc-address localhost:9632

# Validator status
docker exec polygon-edge-node1 polygon-edge ibft status --grpc-address localhost:9632
```

### Restart Services
```bash
# Restart blockchain only
docker restart polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4

# Restart all services
docker-compose restart
```
