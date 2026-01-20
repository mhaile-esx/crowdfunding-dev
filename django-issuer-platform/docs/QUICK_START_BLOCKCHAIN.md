# 🚀 CrowdfundChain Blockchain Quick Start

## ✅ **Solution: Use Hardhat Network (No Docker Required)**

Since ESX doesn't support Docker, we use **Hardhat Network** - a local Ethereum blockchain that works perfectly for development.

---

## 📋 **3-Step Setup**

### **Step 1: Start Blockchain Network**

Open a terminal and run:

```bash
./start-blockchain.sh
```

You'll see:
```
🔗 CrowdfundChain Blockchain Network
Network: Hardhat Local
RPC URL: http://localhost:8545
Starting blockchain...

Started HTTP and WebSocket JSON-RPC server at http://0.0.0.0:8545/

Accounts
========
Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
...
```

**✨ Keep this terminal running!**

---

### **Step 2: Deploy Smart Contracts**

Open a **new terminal** and run:

```bash
./deploy-contracts.sh
```

You'll see:
```
📜 CrowdfundChain Contract Deployment
✓ Blockchain network is running
→ Deploying smart contracts...

Deploying CampaignFactory...
✅ CampaignFactory deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3

Deploying IssuerRegistry...
✅ IssuerRegistry deployed to: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

... (more contracts)

✅ Contracts deployed successfully!
```

**💡 Copy the contract addresses!**

---

### **Step 3: Start Your Application**

Keep blockchain running, then in a **third terminal**:

```bash
npm run dev
```

Your app now connects to the local blockchain at `http://localhost:8545`! 🎉

---

## 🔧 **Configuration**

The blockchain config is already set up in `shared/blockchain-config.ts`:

```typescript
local: {
  name: "CrowdfundChain Local",
  chainId: 1337,
  rpcUrl: "http://localhost:8545", // ✅ Already configured
  nativeCurrency: {
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
  },
}
```

**No changes needed!** It works out of the box.

---

## 🧪 **Testing the Blockchain**

### **Check Network is Running:**

```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545
```

**Expected response:**
```json
{"jsonrpc":"2.0","id":1,"result":"0xa"}
```

### **Get Account Balance:**

```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' \
  http://localhost:8545
```

---

## 📝 **Pre-funded Test Accounts**

Hardhat provides 20 accounts, each with **10,000 ETH**:

```javascript
// Account #0 (use this for testing)
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// Account #1
Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

// Use these in MetaMask or your tests
```

---

## 🔄 **Common Commands**

### **Reset Blockchain (Fresh Start):**
```bash
# Stop blockchain (Ctrl+C in blockchain terminal)
# Clean cache
npx hardhat clean
# Start again
./start-blockchain.sh
```

### **Re-deploy Contracts:**
```bash
./deploy-contracts.sh
```

### **Check Hardhat Config:**
```bash
cat hardhat.config.cjs
```

---

## 🆚 **Hardhat vs. Polygon Local Network**

| Feature | Hardhat Network | Polygon (Docker) |
|---------|----------------|------------------|
| **Works in ESX** | ✅ Yes | ❌ No |
| **Setup Time** | 10 seconds | 10+ minutes |
| **Resources** | Lightweight | Heavy |
| **Contract Compatibility** | ✅ 100% | ✅ 100% |
| **Development Speed** | ⚡ Instant | 🐌 Slow |
| **Production Ready** | Development only | Testing/Staging |

**Bottom Line:** Use Hardhat for development, test on Mumbai/Polygon later.

---

## 🚀 **Next Steps**

### **For Development (Now):**
1. ✅ Use Hardhat Network (local)
2. ✅ Develop and test features
3. ✅ Build your application

### **For Testing (Later):**
1. Deploy to **Polygon Mumbai Testnet**
2. Get free test MATIC from faucet
3. Test with real Polygon network

### **For Production (Final):**
1. Deploy to **Polygon Mainnet**
2. Use production RPC endpoints
3. Launch to users

---

## ❓ **FAQ**

### **Q: Will my contracts work the same on Hardhat and Polygon?**
**A:** Yes! 100% compatible. Same Solidity, same APIs, same everything.

### **Q: Can I use MetaMask with Hardhat?**
**A:** Yes! Add custom network in MetaMask:
- Network Name: Hardhat Local
- RPC URL: http://localhost:8545
- Chain ID: 31337
- Currency Symbol: ETH

### **Q: How do I switch to Mumbai testnet later?**
**A:** Just set environment variable:
```bash
export BLOCKCHAIN_NETWORK=mumbai
```

### **Q: What about the Polygon deployment scripts?**
**A:** They're for Docker-based deployments on external servers. Not needed for ESX development.

---

## 📚 **Documentation**

- **Full Guide:** `REPLIT_BLOCKCHAIN_SETUP.md`
- **Troubleshooting:** `POLYGON_DEPLOYMENT_TROUBLESHOOTING.md`
- **Hardhat Docs:** https://hardhat.org/
- **Polygon Docs:** https://docs.polygon.technology/

---

## ✅ **Summary**

```bash
# Terminal 1: Start blockchain
./start-blockchain.sh

# Terminal 2: Deploy contracts (wait for Terminal 1 to be ready)
./deploy-contracts.sh

# Terminal 3: Start your app
npm run dev
```

**That's it!** No Docker, no complexity, just works. 🎉

---

**Questions?** Check `REPLIT_BLOCKCHAIN_SETUP.md` for detailed explanations.
