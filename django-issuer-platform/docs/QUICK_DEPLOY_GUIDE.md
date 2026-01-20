# ⚡ Quick Deploy Guide - Polygon Edge

**FIXED:** NPX module conflicts resolved! Use the methods below.

---

## ✅ Solution: Avoid NPX Conflicts

Your project uses ES modules, which conflicts with `npx hardhat`. Use one of these methods instead:

### **Method 1: Use Helper Script (Easiest)** ⭐

```bash
# Make script executable (first time only)
chmod +x deploy-blockchain.sh

# Test connection
./deploy-blockchain.sh test

# Deploy contracts
./deploy-blockchain.sh deploy

# Check balance
./deploy-blockchain.sh balance

# Transfer ETH
./deploy-blockchain.sh transfer 0xRECIPIENT_ADDRESS 100

# Open console
./deploy-blockchain.sh console
```

### **Method 2: Use Local Hardhat Binary**

```bash
# Test connection
./node_modules/.bin/hardhat run scripts/test-connection.cjs --network polygon-edge

# Deploy contracts
./node_modules/.bin/hardhat run scripts/deploy-polygon-edge.cjs --network polygon-edge

# Check balance
./node_modules/.bin/hardhat run scripts/check-balance.cjs --network polygon-edge

# Console
./node_modules/.bin/hardhat console --network polygon-edge
```

---

## 🚀 Full Deployment Steps

### **On Your VPS** (Recommended)

1. **Get validator private key:**
```bash
cd ~/source/scripts/polygon-edge
./polygon-edge secrets output --data-dir test-chain-1
```

2. **Setup project on VPS:**
```bash
cd ~/source/scripts/
# Copy your CrowdfundChain code here
# Make sure hardhat.config.cjs and scripts/ folder are present
```

3. **Configure environment:**
```bash
nano .env
```
Add:
```env
POLYGON_EDGE_RPC_URL=http://localhost:8545
POLYGON_EDGE_PRIVATE_KEY=your_validator_private_key_here
```

4. **Deploy:**
```bash
# Test connection
./deploy-blockchain.sh test

# Expected output:
# ✅ Connection successful! Ready to deploy.

# Deploy contracts
./deploy-blockchain.sh deploy
```

### **From Local Machine**

Same steps, but use VPS IP in .env:
```env
POLYGON_EDGE_RPC_URL=http://172.80.80.144:8545
POLYGON_EDGE_PRIVATE_KEY=your_validator_private_key_here
```

---

## 📊 Expected Output

### ✅ Successful Connection

```
🔗 CrowdfundChain Blockchain Deployment Helper

Testing connection to Polygon Edge...
🔗 Testing Polygon Edge Connection...

Network Name: unknown
Chain ID: 100
Current Block: 5678
Deployer Address: 0x85ef83508D55Dc54664FC1B774F3c089e37Eb269
Deployer Balance: 999.8 ETH

✅ Connection successful! Ready to deploy.
```

### ✅ Successful Deployment

```
🔗 CrowdfundChain Blockchain Deployment Helper

Deploying contracts to Polygon Edge...
📜 Deploying CrowdfundChain Contracts to Polygon Edge...

Deploying with account: 0x85ef83508D55Dc54664FC1B774F3c089e37Eb269
Account balance: 999.8 ETH

✅ Deployment complete!
Contract addresses saved to: deployments-polygon-edge.json
```

---

## ⚠️ Common Errors & Fixes

### ❌ Error: `SyntaxError: Unexpected reserved word`

**Cause:** Using `npx hardhat` with ES modules

**Fix:** Use helper script or local binary:
```bash
./deploy-blockchain.sh test
# OR
./node_modules/.bin/hardhat run scripts/test-connection.cjs --network polygon-edge
```

### ❌ Error: `Cannot connect to network`

**Cause:** Running from wrong location (e.g., ESX)

**Fix:** Run from VPS or local machine with network access

### ❌ Error: `Insufficient funds`

**Cause:** Wrong private key (no ETH)

**Fix:** Use validator key with premined ETH

---

## 📋 Quick Command Reference

```bash
# Helper script commands
./deploy-blockchain.sh test           # Test connection
./deploy-blockchain.sh deploy         # Deploy contracts
./deploy-blockchain.sh balance        # Check balance
./deploy-blockchain.sh console        # Open console
./deploy-blockchain.sh transfer <to> <amount>  # Transfer ETH

# Direct commands (alternative)
./node_modules/.bin/hardhat run scripts/test-connection.cjs --network polygon-edge
./node_modules/.bin/hardhat run scripts/deploy-polygon-edge.cjs --network polygon-edge
./node_modules/.bin/hardhat console --network polygon-edge
```

---

## 🎯 What's Been Fixed

✅ **Scripts renamed to .cjs** - Avoids ES module conflicts  
✅ **Helper script created** - Easy deployment commands  
✅ **Local hardhat usage** - No more npx conflicts  
✅ **Complete documentation** - Step-by-step guides

---

## 📚 Full Documentation

- **DEPLOY_CONTRACTS_GUIDE.md** - Complete deployment guide
- **DEPLOYMENT_INSTRUCTIONS.md** - Where to run commands
- **CONTRACT_DEPLOYMENT_READY.md** - System overview
- **QUICK_DEPLOY_GUIDE.md** - This quick reference

---

**Ready to deploy!** 🚀

Use `./deploy-blockchain.sh test` to get started.
