# Quick Start Guide - CrowdfundChain Polygon Edge Network

## 🚀 5-Minute Deployment on VPS

This guide is for deploying the **Polygon Edge 4-node IBFT validator network** on your VPS or local machine with Docker.

**Note:** For ESX development, use the Hardhat Network instead (see `QUICK_START_BLOCKCHAIN.md`).

---

## Prerequisites Check

```bash
# Verify Docker installed
docker --version  # Should be 20.10+

# Verify Docker Compose installed
docker-compose --version  # Should be 1.29+

# Verify Docker is running
docker ps
```

---

## 📦 Step 1: Run Deployment Script

```bash
# Make script executable
chmod +x polygon-deploy.sh

# Run deployment
./polygon-deploy.sh
```

The script will:
- ✅ Download Polygon Edge v1.3.1
- ✅ Generate validator secrets for 4 nodes
- ✅ Create genesis configuration
- ✅ Set up Docker Compose
- ✅ Create management scripts

**Expected Output:**
```
╔════════════════════════════════════════════════════════════════╗
║  ✅ DEPLOYMENT COMPLETE!                                       ║
╚════════════════════════════════════════════════════════════════╝

Network files created in: /path/to/polygon-edge

Next Steps:
  1. cd polygon-edge
  2. ./start.sh              # Start the network
  3. ./monitor.sh            # Check status
```

---

## 🚀 Step 2: Start the Network

```bash
cd polygon-edge
./start.sh
```

**Expected Output:**
```
🚀 Starting CrowdfundChain Polygon Edge Network...
Creating network "polygon-edge_edge-network" with driver "bridge"
Creating node1 ... done
Creating node2 ... done
Creating node3 ... done
Creating node4 ... done
✅ Network started

Monitor with: ./monitor.sh
View logs with: ./logs.sh
```

---

## ✅ Step 3: Verify Network

Wait 30-60 seconds for nodes to connect, then check status:

```bash
./monitor.sh
```

**Expected Output:**
```
=== CrowdfundChain Polygon Edge Network Status ===

📦 Container Status:
NAME      STATUS          PORTS
node1     Up 2 minutes    0.0.0.0:8545->8545/tcp
node2     Up 2 minutes    
node3     Up 2 minutes    
node4     Up 2 minutes    

🔗 Blockchain Status:
  ✅ Current Block: 42
  ✅ RPC Endpoint: http://localhost:8545
  ✅ Chain ID: 100

🌐 Network Info:
Peer connected: id=16Uiu2HAmByAzCv1E...
Peer connected: id=16Uiu2HAkxgweeorY...
Peer connected: id=16Uiu2HAmPtzHmBXk...
```

---

## 🧪 Step 4: Test Connectivity

```bash
# Check block number
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Expected Output:**
```json
{"jsonrpc":"2.0","id":1,"result":"0x2a"}
```

```bash
# Check chain ID
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

**Expected Output:**
```json
{"jsonrpc":"2.0","id":1,"result":"0x64"}
```
*(0x64 = 100 in decimal)*

---

## 📊 Network Configuration

### RPC Endpoint
- **Primary RPC**: http://localhost:8545 (or http://YOUR_VPS_IP:8545)
- **Chain ID**: 100
- **Consensus**: IBFT (4 validators)
- **Block Time**: ~2 seconds

### Validator Nodes
- **Node 1**: Bootnode + RPC (port 8545)
- **Node 2**: Validator
- **Node 3**: Validator
- **Node 4**: Validator

---

## 🔐 Connect to MetaMask

1. **Open MetaMask** → Settings → Networks → Add Network

2. **Enter Details:**
   - Network Name: `CrowdfundChain Polygon Edge`
   - RPC URL: `http://YOUR_VPS_IP:8545`
   - Chain ID: `100`
   - Currency Symbol: `ETH`

3. **Import Premined Account:**
   
   The genesis includes a premined account with 1000 ETH:
   ```
   Address: 0x85da99c8a7c2c95964c8efd687e95e632fc423a6
   ```
   
   To get the private key, check your validator secrets:
   ```bash
   cd polygon-edge
   cat test-chain-1/consensus/validator-key
   ```

---

## 💻 Connect from Application

### Update Environment Variables

```bash
# Add to your .env file
POLYGON_RPC_URL=http://YOUR_VPS_IP:8545
POLYGON_CHAIN_ID=100
POLYGON_NETWORK_NAME=crowdfundchain-polygon-edge
```

### Update blockchain-config.ts

```typescript
// shared/blockchain-config.ts
export const BLOCKCHAIN_NETWORKS = {
  local: {
    name: "CrowdfundChain Local",
    chainId: 1337,
    rpcUrl: "http://localhost:8545" // Hardhat
  },
  production: {
    name: "CrowdfundChain Polygon Edge",
    chainId: 100,
    rpcUrl: "http://YOUR_VPS_IP:8545", // ← Your VPS
    nativeCurrency: {
      name: "Ethereum",
      symbol: "ETH",
      decimals: 18
    }
  }
};
```

### Test Connection (Node.js)

```javascript
const { ethers } = require('ethers');

const provider = new ethers.JsonRpcProvider('http://YOUR_VPS_IP:8545');

async function test() {
  const blockNumber = await provider.getBlockNumber();
  console.log('Current block:', blockNumber);
  
  const network = await provider.getNetwork();
  console.log('Chain ID:', network.chainId);
}

test();
```

---

## 🛠️ Management Commands

All commands should be run from the `polygon-edge/` directory:

```bash
cd polygon-edge

# Start network
./start.sh

# Stop network
./stop.sh

# Restart network
./restart.sh

# Monitor status
./monitor.sh

# View logs (all nodes)
./logs.sh

# View logs (specific node)
./logs.sh node1
```

---

## 📁 Directory Structure

```
polygon-edge/
├── genesis.json               # Network genesis configuration
├── docker-compose.yml         # Container orchestration
├── polygon-edge               # Polygon Edge binary
├── test-chain-1/              # Node 1 data & secrets
│   ├── consensus/             # Validator keys
│   └── blockchain/            # Blockchain data
├── test-chain-2/              # Node 2 data & secrets
├── test-chain-3/              # Node 3 data & secrets
├── test-chain-4/              # Node 4 data & secrets
├── start.sh                   # Start network
├── stop.sh                    # Stop network
├── restart.sh                 # Restart network
├── monitor.sh                 # Check status
├── logs.sh                    # View logs
└── README.md                  # Detailed documentation
```

---

## ⚠️ Troubleshooting

### Issue: Containers won't start

```bash
# Check if port 8545 is in use
sudo netstat -tulpn | grep 8545

# View container logs
docker-compose logs node1

# Clean up and retry
docker-compose down
docker-compose up -d
```

### Issue: Nodes not connecting

```bash
# Check bootnode is running
docker logs node1 | grep "LibP2P"

# Check peer connections
docker logs node2 | grep "peer"

# Restart network
./restart.sh
```

### Issue: Can't connect to RPC

```bash
# Verify container is running
docker-compose ps

# Test from inside container
docker exec node1 wget -qO- http://localhost:8545

# Check firewall (if on VPS)
sudo ufw status
sudo ufw allow 8545/tcp
```

### Issue: Block production stopped

```bash
# Check consensus logs
docker logs node1 | grep consensus

# Restart all nodes
./restart.sh
```

### Reset Network (Nuclear Option)

```bash
cd polygon-edge
./stop.sh

# Remove blockchain data (keeps validator keys)
rm -rf test-chain-*/blockchain

./start.sh
```

---

## 🔒 Security Checklist

For production deployments:

- [ ] Configure firewall: Only allow port 8545 from application servers
- [ ] Enable SSL/TLS reverse proxy (Nginx/Caddy) for RPC endpoint
- [ ] Backup validator secrets: `test-chain-*/consensus/`
- [ ] Set proper file permissions: `chmod 600 test-chain-*/consensus/*`
- [ ] Monitor disk space (blockchain data grows over time)
- [ ] Set up log rotation for Docker containers
- [ ] Configure network-level access controls
- [ ] Regular backups of blockchain data

---

## 📊 Production Deployment Tips

### Use Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl;
    server_name rpc.crowdfundchain.africa;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8545;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Monitor with Systemd

Create `/etc/systemd/system/polygon-edge.service`:

```ini
[Unit]
Description=CrowdfundChain Polygon Edge Network
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/polygon-edge
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable polygon-edge
sudo systemctl start polygon-edge
```

---

## 📚 Next Steps

1. **Deploy Smart Contracts**: Use Hardhat targeting your Polygon Edge RPC
2. **Configure Monitoring**: Set up Prometheus + Grafana
3. **Enable Auto-Backup**: Schedule daily blockchain backups
4. **Load Testing**: Test network capacity before production
5. **Documentation**: Update team documentation with network details

---

## 🆘 Support

**Need Help?**
- Detailed README: `polygon-edge/README.md`
- Polygon Edge Docs: https://docs.polygon.technology/docs/edge/
- CrowdfundChain DevOps: devops@crowdfundchain.africa

---

## 📝 Quick Reference Commands

```bash
# Deployment
./polygon-deploy.sh

# Start/Stop
cd polygon-edge
./start.sh
./stop.sh
./restart.sh

# Monitoring
./monitor.sh
./logs.sh
docker-compose ps

# Testing
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# View validator info
cd polygon-edge
./polygon-edge secrets output --data-dir test-chain-1
```

---

**Deployment Time:** ~5 minutes  
**Network Start Time:** ~60 seconds  
**Production Ready:** ✅ Yes (with security hardening)
