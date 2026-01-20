#!/bin/bash

################################################################################
# CrowdfundChain - Smart Contract Deployment Script
# Deploys all contracts to local blockchain network
# Supports both Hardhat (development) and Polygon Edge (VPS production)
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "📜 CrowdfundChain Contract Deployment"
echo "========================================"
echo ""

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

RPC_URL="${RPC_URL:-http://localhost:8545}"

# Check if network is running
log_step "Checking if blockchain network is running at ${RPC_URL}..."
if ! curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  ${RPC_URL} > /dev/null 2>&1; then
    log_error "Blockchain network is not running!"
    echo ""
    echo "Please start the network first:"
    echo "  Development (Hardhat): ./start-blockchain.sh"
    echo "  VPS (Polygon Edge): docker-compose up -d polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4"
    echo ""
    exit 1
fi

log_info "Blockchain network is running"
echo ""

# Check for Polygon Edge private key (VPS deployment)
if [ -n "$POLYGON_EDGE_PRIVATE_KEY" ]; then
    log_info "Using Polygon Edge private key for deployment"
elif [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep POLYGON_EDGE_PRIVATE_KEY | xargs 2>/dev/null) || true
    if [ -n "$POLYGON_EDGE_PRIVATE_KEY" ]; then
        log_info "Loaded Polygon Edge private key from .env"
    fi
fi

# Compile contracts first
log_step "Compiling smart contracts..."
echo ""

npx hardhat compile

if [ $? -ne 0 ]; then
    log_error "Contract compilation failed"
    exit 1
fi

log_info "Contracts compiled successfully"
echo ""

# Deploy contracts - try .cjs first (Polygon Edge compatible), then .js
log_step "Deploying smart contracts to local network..."
echo ""

DEPLOY_SCRIPT=""
if [ -f "smart-contracts/deploy/deploy.cjs" ]; then
    DEPLOY_SCRIPT="smart-contracts/deploy/deploy.cjs"
elif [ -f "smart-contracts/deploy/deploy.js" ]; then
    DEPLOY_SCRIPT="smart-contracts/deploy/deploy.js"
fi

if [ -n "$DEPLOY_SCRIPT" ]; then
    npx hardhat run ${DEPLOY_SCRIPT} --network localhost
    
    if [ $? -eq 0 ]; then
        echo ""
        log_info "✅ Contracts deployed successfully!"
        echo ""
        
        # Update .env with contract addresses if deployment-info.json exists
        if [ -f "deployment-info.json" ]; then
            log_step "Contract addresses saved to deployment-info.json"
            
            if ! grep -q "CONTRACT_NFT_CERTIFICATE" .env 2>/dev/null; then
                NFT_ADDR=$(grep -o '"nftShareCertificate":"[^"]*"' deployment-info.json 2>/dev/null | cut -d'"' -f4)
                DAO_ADDR=$(grep -o '"daoGovernance":"[^"]*"' deployment-info.json 2>/dev/null | cut -d'"' -f4)
                FACTORY_ADDR=$(grep -o '"campaignFactory":"[^"]*"' deployment-info.json 2>/dev/null | cut -d'"' -f4)
                IMPL_ADDR=$(grep -o '"campaignImplementation":"[^"]*"' deployment-info.json 2>/dev/null | cut -d'"' -f4)
                
                if [ -n "$NFT_ADDR" ]; then
                    cat >> .env << EOF

# Smart Contract Addresses (deployed $(date +%Y-%m-%d))
CONTRACT_NFT_CERTIFICATE=${NFT_ADDR}
CONTRACT_DAO_GOVERNANCE=${DAO_ADDR}
CONTRACT_CAMPAIGN_FACTORY=${FACTORY_ADDR}
CONTRACT_CAMPAIGN_IMPLEMENTATION=${IMPL_ADDR}
EOF
                    log_info "Contract addresses appended to .env"
                fi
            else
                log_warn "Contract addresses already in .env - update manually if needed"
            fi
        fi
        
        echo ""
        echo "Next steps:"
        echo "  1. Check deployed addresses in deployment-info.json"
        echo "  2. Restart Django to load new contract addresses (if VPS):"
        echo "     docker-compose restart django"
        echo ""
    else
        log_error "Contract deployment failed"
        exit 1
    fi
else
    log_error "Deployment script not found!"
    echo "Expected: smart-contracts/deploy/deploy.cjs or smart-contracts/deploy/deploy.js"
    exit 1
fi
