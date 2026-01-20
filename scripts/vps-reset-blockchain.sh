#!/bin/bash
##############################################################################
# CrowdfundChain VPS Blockchain Reset Script
# Clears blockchain data and regenerates genesis (DESTRUCTIVE)
#
# Usage: ./scripts/vps-reset-blockchain.sh
# WARNING: This will delete all blockchain data!
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

POLYGON_EDGE_VERSION="1.3.1"
POLYGON_EDGE_IMAGE="0xpolygon/polygon-edge:${POLYGON_EDGE_VERSION}"
BASE_DIR="${PWD}/polygon-edge"
CHAIN_ID="${CHAIN_ID:-100}"
DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-0x49065C1C0cFc356313eB67860bD6b697a9317a83}"

log_section "CrowdfundChain Blockchain Reset"

echo -e "${RED}${BOLD}WARNING: This will delete ALL blockchain data!${NC}"
echo "All transactions, deployed contracts, and state will be lost."
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

##############################################################################
log_section "Step 1: Stop Blockchain Nodes"
##############################################################################

log_step "Stopping all Polygon Edge nodes..."
docker stop polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4 2>/dev/null || true
log_info "Nodes stopped"

##############################################################################
log_section "Step 2: Clear Blockchain Data"
##############################################################################

log_step "Clearing blockchain data (preserving validator keys)..."

for i in 1 2 3 4; do
    rm -rf "${BASE_DIR}/node-${i}/blockchain" 2>/dev/null || true
    rm -rf "${BASE_DIR}/node-${i}/trie" 2>/dev/null || true
    rm -f "${BASE_DIR}/node-${i}/consensus/metadata" 2>/dev/null || true
    rm -f "${BASE_DIR}/node-${i}/consensus/snapshots" 2>/dev/null || true
    log_info "Cleared data for node-${i}"
done

##############################################################################
log_section "Step 3: Regenerate Genesis"
##############################################################################

if [ ! -f "${BASE_DIR}/node-1/address.txt" ]; then
    log_error "Validator addresses not found. Run vps-setup-polygon-edge.sh first."
    exit 1
fi

V1_ADDR=$(cat "${BASE_DIR}/node-1/address.txt")
V2_ADDR=$(cat "${BASE_DIR}/node-2/address.txt")
V3_ADDR=$(cat "${BASE_DIR}/node-3/address.txt")
V4_ADDR=$(cat "${BASE_DIR}/node-4/address.txt")

V1_BLS=$(cat "${BASE_DIR}/node-1/bls-public.txt" | sed 's/^0x//')
V2_BLS=$(cat "${BASE_DIR}/node-2/bls-public.txt" | sed 's/^0x//')
V3_BLS=$(cat "${BASE_DIR}/node-3/bls-public.txt" | sed 's/^0x//')
V4_BLS=$(cat "${BASE_DIR}/node-4/bls-public.txt" | sed 's/^0x//')

NODE1_ID=$(cat "${BASE_DIR}/node-1/node-id.txt")
BOOTNODE="/ip4/172.20.0.10/tcp/1478/p2p/${NODE1_ID}"

log_step "Regenerating genesis with existing validators..."

rm -f "${BASE_DIR}/genesis.json"
rm -f /tmp/genesis.json

docker run --rm -v /tmp:/output ${POLYGON_EDGE_IMAGE} genesis \
    --consensus ibft \
    --ibft-validator "${V1_ADDR}:${V1_BLS}" \
    --ibft-validator "${V2_ADDR}:${V2_BLS}" \
    --ibft-validator "${V3_ADDR}:${V3_BLS}" \
    --ibft-validator "${V4_ADDR}:${V4_BLS}" \
    --bootnode "${BOOTNODE}" \
    --premine "${V1_ADDR}:1000000000000000000000000" \
    --premine "${V2_ADDR}:1000000000000000000000000" \
    --premine "${V3_ADDR}:1000000000000000000000000" \
    --premine "${V4_ADDR}:1000000000000000000000000" \
    --premine "${DEPLOYER_ADDRESS}:1000000000000000000000000" \
    --chain-id ${CHAIN_ID} \
    --block-gas-limit 10000000 \
    --dir /output/genesis.json

cp /tmp/genesis.json "${BASE_DIR}/genesis.json"
log_info "Genesis regenerated"

##############################################################################
log_section "Step 4: Restart Nodes"
##############################################################################

log_step "Starting blockchain nodes..."
docker start polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4

log_step "Waiting for consensus (30 seconds)..."
sleep 30

##############################################################################
log_section "Step 5: Verify"
##############################################################################

BLOCK_NUM=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

BLOCK_DEC=$((16#${BLOCK_NUM#0x}))

if [ "$BLOCK_DEC" -gt 0 ]; then
    log_info "Blockchain producing blocks! Current block: #${BLOCK_DEC}"
else
    log_warn "Block number is still 0 - consensus may need more time"
    echo "Check logs: docker logs polygon-edge-node1 --tail 20"
fi

##############################################################################
log_section "Reset Complete!"
##############################################################################

echo -e "
${GREEN}Blockchain has been reset!${NC}

${BOLD}Deployer Account:${NC}
  Address: ${DEPLOYER_ADDRESS}
  Balance: 1,000,000 ETH (premined)

${BOLD}Next Steps:${NC}
  1. Verify blockchain is producing blocks:
     curl -s http://localhost:8545 -X POST -H 'Content-Type: application/json' \\
          -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'

  2. Deploy smart contracts:
     ./scripts/vps-deploy-contracts.sh

${BOLD}Note:${NC}
  All previous transactions and contracts have been deleted.
  You need to redeploy all smart contracts.
"
