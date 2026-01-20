#!/bin/bash
##############################################################################
# CrowdfundChain VPS Smart Contract Deployment Script
# Deploys all contracts to Polygon Edge network
#
# Usage: ./scripts/vps-deploy-contracts.sh
# Requires: Polygon Edge network running
##############################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_section() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}\n"; }
log_step() { echo -e "  ${BLUE}[→]${NC} $1"; }
log_info() { echo -e "  ${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "  ${RED}[✗]${NC} $1"; }

RPC_URL="${RPC_URL:-http://localhost:8545}"

log_section "CrowdfundChain Smart Contract Deployment"

##############################################################################
log_section "Step 1: Environment Check"
##############################################################################

if [ -z "$POLYGON_EDGE_PRIVATE_KEY" ]; then
    if [ -f ".env" ]; then
        log_step "Loading environment from .env file..."
        export $(grep -v '^#' .env | grep POLYGON_EDGE_PRIVATE_KEY | xargs)
    fi
fi

if [ -z "$POLYGON_EDGE_PRIVATE_KEY" ]; then
    log_error "POLYGON_EDGE_PRIVATE_KEY not set!"
    echo ""
    echo "Set it in .env file or export it:"
    echo "  export POLYGON_EDGE_PRIVATE_KEY=0x..."
    exit 1
fi

log_info "Private key configured"

##############################################################################
log_section "Step 2: Network Connectivity"
##############################################################################

log_step "Checking blockchain connectivity..."
BLOCK_NUM=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    ${RPC_URL} | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BLOCK_NUM" ]; then
    log_error "Cannot connect to blockchain at ${RPC_URL}"
    echo ""
    echo "Start the blockchain first:"
    echo "  docker-compose up -d polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4"
    exit 1
fi

BLOCK_DEC=$((16#${BLOCK_NUM#0x}))
log_info "Blockchain running at block #${BLOCK_DEC}"

if [ "$BLOCK_DEC" -eq 0 ]; then
    log_warn "Block number is 0 - waiting for consensus..."
    sleep 30
    BLOCK_NUM=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        ${RPC_URL} | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    BLOCK_DEC=$((16#${BLOCK_NUM#0x}))
    if [ "$BLOCK_DEC" -eq 0 ]; then
        log_error "Blockchain not producing blocks! Check node consensus."
        exit 1
    fi
    log_info "Blockchain now at block #${BLOCK_DEC}"
fi

##############################################################################
log_section "Step 3: Check Deployer Balance"
##############################################################################

DEPLOYER_ADDR=$(node -e "console.log(require('ethers').computeAddress('$POLYGON_EDGE_PRIVATE_KEY'))" 2>/dev/null)
log_step "Deployer address: ${DEPLOYER_ADDR}"

BALANCE=$(node -e "
const {ethers} = require('ethers');
const p = new ethers.JsonRpcProvider('${RPC_URL}');
p.getBalance('${DEPLOYER_ADDR}').then(b => console.log(ethers.formatEther(b)));
" 2>/dev/null)

log_info "Deployer balance: ${BALANCE} ETH"

if [ "$(echo "$BALANCE == 0" | bc -l 2>/dev/null || echo 1)" = "1" ] && [ "$BALANCE" = "0.0" ]; then
    log_error "Deployer has 0 balance! Fund the account first."
    exit 1
fi

##############################################################################
log_section "Step 4: Compile Contracts"
##############################################################################

log_step "Compiling smart contracts..."
npx hardhat compile

if [ $? -ne 0 ]; then
    log_error "Contract compilation failed"
    exit 1
fi

log_info "Contracts compiled successfully"

##############################################################################
log_section "Step 5: Deploy Contracts"
##############################################################################

log_step "Deploying to Polygon Edge network..."

DEPLOY_SCRIPT="smart-contracts/deploy/deploy.cjs"
if [ ! -f "$DEPLOY_SCRIPT" ]; then
    DEPLOY_SCRIPT="smart-contracts/deploy/deploy.js"
fi

if [ ! -f "$DEPLOY_SCRIPT" ]; then
    log_error "Deployment script not found!"
    exit 1
fi

npx hardhat run ${DEPLOY_SCRIPT} --network localhost

if [ $? -ne 0 ]; then
    log_error "Contract deployment failed"
    exit 1
fi

log_info "Contracts deployed successfully"

##############################################################################
log_section "Step 6: Update Environment"
##############################################################################

if [ -f "deployment-info.json" ]; then
    log_step "Extracting contract addresses..."
    
    NFT_ADDR=$(grep -o '"nftShareCertificate":"[^"]*"' deployment-info.json | cut -d'"' -f4)
    DAO_ADDR=$(grep -o '"daoGovernance":"[^"]*"' deployment-info.json | cut -d'"' -f4)
    FACTORY_ADDR=$(grep -o '"campaignFactory":"[^"]*"' deployment-info.json | cut -d'"' -f4)
    IMPL_ADDR=$(grep -o '"campaignImplementation":"[^"]*"' deployment-info.json | cut -d'"' -f4)
    
    if [ -n "$NFT_ADDR" ]; then
        log_info "NFTShareCertificate: ${NFT_ADDR}"
        log_info "DAOGovernance: ${DAO_ADDR}"
        log_info "CampaignFactory: ${FACTORY_ADDR}"
        log_info "CampaignImplementation: ${IMPL_ADDR}"
        
        if grep -q "CONTRACT_NFT_CERTIFICATE" .env 2>/dev/null; then
            log_warn "Contract addresses already in .env - update manually if needed"
        else
            cat >> .env << EOF

# Smart Contract Addresses (deployed $(date +%Y-%m-%d))
CONTRACT_NFT_CERTIFICATE=${NFT_ADDR}
CONTRACT_DAO_GOVERNANCE=${DAO_ADDR}
CONTRACT_CAMPAIGN_FACTORY=${FACTORY_ADDR}
CONTRACT_CAMPAIGN_IMPLEMENTATION=${IMPL_ADDR}
EOF
            log_info "Contract addresses added to .env"
        fi
    fi
fi

##############################################################################
log_section "Deployment Complete!"
##############################################################################

echo -e "
${GREEN}Smart contracts deployed successfully!${NC}

${BOLD}Next Steps:${NC}
  1. Verify contract addresses in deployment-info.json
  2. Update Django settings if needed
  3. Restart Django to load new contract addresses:
     docker-compose restart django

${BOLD}Test the deployment:${NC}
  curl -s ${RPC_URL} -X POST -H 'Content-Type: application/json' \\
       -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"${NFT_ADDR:-CONTRACT_ADDRESS}\",\"latest\"],\"id\":1}'
"
