#!/bin/bash
##############################################################################
# CrowdfundChain Polygon Edge Setup Script
# Initializes 4-node IBFT consensus network
##############################################################################

set -e

# Colors
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
GENESIS_DIR="${BASE_DIR}/genesis"
VALIDATORS_DIR="${BASE_DIR}/validators"

# Pre-funded accounts (for development/testing)
PREFUNDED_ACCOUNTS=(
    "0x85dA99c8a7C2C95964c8EfD687E95E632Fc533D6:1000000000000000000000000"  # 1M ETH
    "0x0000000000000000000000000000000000000000:0"
)

log_section "CrowdfundChain Polygon Edge Setup"
echo "Version: ${POLYGON_EDGE_VERSION}"
echo "Base directory: ${BASE_DIR}"

##############################################################################
log_section "Step 1: Creating Directory Structure"
##############################################################################

mkdir -p "${GENESIS_DIR}"
mkdir -p "${VALIDATORS_DIR}/validator1"
mkdir -p "${VALIDATORS_DIR}/validator2"
mkdir -p "${VALIDATORS_DIR}/validator3"
mkdir -p "${VALIDATORS_DIR}/validator4"

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
    local dir="${VALIDATORS_DIR}/validator${num}"
    
    log_step "Generating keys for validator ${num}..."
    
    # Generate secrets
    docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets init --data-dir /data --insecure 2>/dev/null
    
    # Extract node ID
    NODE_ID=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "Node ID" | awk '{print $NF}')
    
    # Extract validator address
    VALIDATOR_ADDR=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "Public key (address)" | awk '{print $NF}')
    
    # Extract BLS public key
    BLS_KEY=$(docker run --rm -v "${dir}:/data" ${POLYGON_EDGE_IMAGE} \
        secrets output --data-dir /data 2>/dev/null | grep "BLS Public key" | awk '{print $NF}')
    
    echo "${NODE_ID}" > "${dir}/node-id.txt"
    echo "${VALIDATOR_ADDR}" > "${dir}/address.txt"
    echo "${BLS_KEY}" > "${dir}/bls-public.txt"
    
    log_info "Validator ${num}: ${VALIDATOR_ADDR}"
}

for i in 1 2 3 4; do
    generate_validator $i
done

##############################################################################
log_section "Step 4: Generating Genesis Block"
##############################################################################

# Get all validator addresses
VALIDATOR1_ADDR=$(cat "${VALIDATORS_DIR}/validator1/address.txt")
VALIDATOR2_ADDR=$(cat "${VALIDATORS_DIR}/validator2/address.txt")
VALIDATOR3_ADDR=$(cat "${VALIDATORS_DIR}/validator3/address.txt")
VALIDATOR4_ADDR=$(cat "${VALIDATORS_DIR}/validator4/address.txt")

# Get bootnode multiaddr
NODE1_ID=$(cat "${VALIDATORS_DIR}/validator1/node-id.txt")
BOOTNODE="/dns4/polygon-edge-node1/tcp/1478/p2p/${NODE1_ID}"

log_step "Creating genesis with IBFT consensus..."
log_step "Bootnode: ${BOOTNODE}"

# Generate genesis
docker run --rm \
    -v "${GENESIS_DIR}:/genesis" \
    -v "${VALIDATORS_DIR}:/validators:ro" \
    ${POLYGON_EDGE_IMAGE} \
    genesis \
    --consensus ibft \
    --ibft-validators-prefix-path /validators/validator \
    --bootnode "${BOOTNODE}" \
    --premine "${VALIDATOR1_ADDR}:1000000000000000000000" \
    --premine "${VALIDATOR2_ADDR}:1000000000000000000000" \
    --premine "${VALIDATOR3_ADDR}:1000000000000000000000" \
    --premine "${VALIDATOR4_ADDR}:1000000000000000000000" \
    --premine "0x85dA99c8a7C2C95964c8EfD687E95E632Fc533D6:1000000000000000000000000" \
    --block-gas-limit 20000000 \
    --chain-id 100100 \
    --dir /genesis

log_info "Genesis block created"

##############################################################################
log_section "Step 5: Setting Permissions"
##############################################################################

chmod -R 755 "${BASE_DIR}"
log_info "Permissions set"

##############################################################################
log_section "Step 6: Verification"
##############################################################################

echo -e "\n${BOLD}Validator Addresses:${NC}"
for i in 1 2 3 4; do
    echo "  Validator ${i}: $(cat ${VALIDATORS_DIR}/validator${i}/address.txt)"
done

echo -e "\n${BOLD}Bootnode:${NC}"
echo "  ${BOOTNODE}"

echo -e "\n${BOLD}Chain ID:${NC} 100100"

if [ -f "${GENESIS_DIR}/genesis.json" ]; then
    log_info "Genesis file created successfully"
else
    log_error "Genesis file not found!"
    exit 1
fi

##############################################################################
log_section "Setup Complete!"
##############################################################################

echo -e "
${GREEN}Polygon Edge network is ready to start!${NC}

${BOLD}To start the blockchain:${NC}
  docker compose -f docker-compose.blockchain.yml up -d

${BOLD}To check status:${NC}
  docker compose -f docker-compose.blockchain.yml ps
  curl -s -X POST http://localhost:8545 -H 'Content-Type: application/json' \\
       -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'

${BOLD}To view logs:${NC}
  docker compose -f docker-compose.blockchain.yml logs -f

${BOLD}Network Configuration:${NC}
  RPC URL: http://localhost:8545
  Chain ID: 100100
  Block Gas Limit: 20,000,000

${BOLD}Pre-funded Account:${NC}
  Address: 0x85dA99c8a7C2C95964c8EfD687E95E632Fc533D6
  Balance: 1,000,000 ETH
"
