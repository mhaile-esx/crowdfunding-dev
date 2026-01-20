#!/bin/bash
##############################################################################
# CrowdfundChain VPS Polygon Edge Setup Script
# Initializes 4-node IBFT consensus network with BLS validators
# 
# Usage: ./scripts/vps-setup-polygon-edge.sh
# Run this ONCE when setting up a new VPS deployment
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

log_section "CrowdfundChain VPS Polygon Edge Setup"
echo "Version: ${POLYGON_EDGE_VERSION}"
echo "Base directory: ${BASE_DIR}"
echo "Chain ID: ${CHAIN_ID}"
echo "Deployer address: ${DEPLOYER_ADDRESS}"

##############################################################################
log_section "Step 1: Creating Directory Structure"
##############################################################################

mkdir -p "${BASE_DIR}/node-1/consensus"
mkdir -p "${BASE_DIR}/node-2/consensus"
mkdir -p "${BASE_DIR}/node-3/consensus"
mkdir -p "${BASE_DIR}/node-4/consensus"

log_info "Directories created"

##############################################################################
log_section "Step 2: Pulling Polygon Edge Image"
##############################################################################

log_step "Pulling ${POLYGON_EDGE_IMAGE}..."
docker pull ${POLYGON_EDGE_IMAGE}
log_info "Image pulled successfully"

##############################################################################
log_section "Step 3: Generating Validator Keys"
##############################################################################

generate_validator() {
    local num=$1
    local dir="${BASE_DIR}/node-${num}"
    
    log_step "Generating keys for validator ${num}..."
    
    docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets init --data-dir /data --insecure 2>/dev/null || true
    
    NODE_ID=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "Node ID" | awk '{print $NF}')
    
    VALIDATOR_ADDR=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "Public key (address)" | awk '{print $NF}')
    
    BLS_KEY=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "BLS Public key" | awk '{print $NF}')
    
    echo "${NODE_ID}" > "${dir}/node-id.txt"
    echo "${VALIDATOR_ADDR}" > "${dir}/address.txt"
    echo "${BLS_KEY}" > "${dir}/bls-public.txt"
    
    log_info "Validator ${num}: ${VALIDATOR_ADDR}"
    log_info "  BLS: ${BLS_KEY}"
}

for i in 1 2 3 4; do
    if [ -f "${BASE_DIR}/node-${i}/consensus/validator.key" ]; then
        log_warn "Validator ${i} keys already exist, extracting info..."
        NODE_ID=$(docker run --rm -v "${BASE_DIR}/node-${i}:/data" ${POLYGON_EDGE_IMAGE} \
            secrets output --data-dir /data 2>/dev/null | grep "Node ID" | awk '{print $NF}')
        VALIDATOR_ADDR=$(docker run --rm -v "${BASE_DIR}/node-${i}:/data" ${POLYGON_EDGE_IMAGE} \
            secrets output --data-dir /data 2>/dev/null | grep "Public key (address)" | awk '{print $NF}')
        BLS_KEY=$(docker run --rm -v "${BASE_DIR}/node-${i}:/data" ${POLYGON_EDGE_IMAGE} \
            secrets output --data-dir /data 2>/dev/null | grep "BLS Public key" | awk '{print $NF}')
        echo "${NODE_ID}" > "${BASE_DIR}/node-${i}/node-id.txt"
        echo "${VALIDATOR_ADDR}" > "${BASE_DIR}/node-${i}/address.txt"
        echo "${BLS_KEY}" > "${BASE_DIR}/node-${i}/bls-public.txt"
        log_info "Validator ${i}: ${VALIDATOR_ADDR}"
    else
        generate_validator $i
    fi
done

##############################################################################
log_section "Step 4: Generating Genesis Block"
##############################################################################

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

log_step "Creating genesis with IBFT BLS consensus..."
log_step "Bootnode: ${BOOTNODE}"

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
log_info "Genesis block created at ${BASE_DIR}/genesis.json"

##############################################################################
log_section "Step 5: Setting Permissions"
##############################################################################

chmod -R 755 "${BASE_DIR}"
log_info "Permissions set"

##############################################################################
log_section "Step 6: Save Configuration"
##############################################################################

cat > "${BASE_DIR}/network-config.txt" << EOF
CrowdfundChain Polygon Edge Network Configuration
Generated: $(date)

Chain ID: ${CHAIN_ID}
Bootnode: ${BOOTNODE}

Validators:
  Node 1: ${V1_ADDR}
  Node 2: ${V2_ADDR}
  Node 3: ${V3_ADDR}
  Node 4: ${V4_ADDR}

Deployer Account: ${DEPLOYER_ADDRESS}

RPC URL: http://localhost:8545
WebSocket: ws://localhost:8545
EOF

log_info "Configuration saved to ${BASE_DIR}/network-config.txt"

##############################################################################
log_section "Setup Complete!"
##############################################################################

echo -e "
${GREEN}Polygon Edge network is ready!${NC}

${BOLD}Validators:${NC}
  Node 1: ${V1_ADDR}
  Node 2: ${V2_ADDR}
  Node 3: ${V3_ADDR}
  Node 4: ${V4_ADDR}

${BOLD}Deployer Account:${NC}
  Address: ${DEPLOYER_ADDRESS}
  Balance: 1,000,000 ETH (premined)

${BOLD}Next Steps:${NC}
  1. Start the blockchain:
     docker-compose up -d polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4

  2. Wait for consensus (~20 seconds):
     sleep 20

  3. Verify blocks are being produced:
     curl -s http://localhost:8545 -X POST -H 'Content-Type: application/json' \\
          -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'

  4. Deploy smart contracts:
     ./scripts/vps-deploy-contracts.sh

${BOLD}Network Configuration:${NC}
  RPC URL: http://localhost:8545
  Chain ID: ${CHAIN_ID}
"
