#!/bin/bash

################################################################################
# CrowdfundChain Africa - Polygon Edge Network Deployment Script
# 4-Node IBFT Validator Setup with Docker
#
# ⚠️  IMPORTANT: FOR EXTERNAL VPS DEPLOYMENT ONLY
# 
# This script uses Polygon Edge v1.3.1 and will NOT work in Repo.
# For Repo development, use: ./start-blockchain.sh (Hardhat Network)
#
# Recommended for:
#   - VPS (DigitalOcean, AWS, Linode, etc.)
#   - Local development machine with Docker
#   - Production-like testing environment
#
# Prerequisites:
#   - Docker installed and running
#   - Docker Compose installed
#   - At least 10GB free disk space
#   - At least 4GB RAM
#   - Port 8545 available for RPC endpoint
#
# Quick Start:
#   1. Run validation: ./validate-polygon-deployment.sh
#   2. Deploy network: ./polygon-deploy.sh
#   3. Monitor network: cd polygon-edge && ./monitor.sh
################################################################################

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="crowdfundchain-polygon-edge"
CHAIN_ID=100
BLOCK_TIME=2
NUM_VALIDATORS=4
POLYGON_EDGE_VERSION="1.3.1"

# Directories
BASE_DIR="$(pwd)/polygon-edge"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Error handler
error_handler() {
    log_error "Deployment failed at line $1"
    log_error "Check error message above for details"
    exit 1
}

trap 'error_handler $LINENO' ERR

# Check environment
check_environment() {
    log_step "Checking deployment environment..."
    
    # Detect if running in Repo
    if [ -n "$REPL_ID" ] || [ -n "$REPL_SLUG" ] || [ -d "/home/runner" ]; then
        log_error "❌ This script cannot run in ESX (Docker not supported)"
        echo ""
        echo "For ESX development, use Hardhat Network instead:"
        echo "  ./start-blockchain.sh"
        echo ""
        echo "See: QUICK_START_BLOCKCHAIN.md for details"
        echo ""
        exit 1
    fi
    
    log_info "✅ Not running in ESX - proceeding with deployment"
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    local failed=0
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        echo "Install: curl -fsSL https://get.docker.com | sh"
        failed=1
    else
        log_info "Docker: $(docker --version)"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        if ! docker compose version &> /dev/null; then
            log_error "Docker Compose is not installed"
            failed=1
        else
            log_info "Docker Compose: $(docker compose version)"
        fi
    else
        log_info "Docker Compose: $(docker-compose --version)"
    fi
    
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        echo "Start Docker: sudo systemctl start docker"
        failed=1
    else
        log_info "Docker daemon is running"
    fi
    
    if [ $failed -eq 1 ]; then
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

create_directories() {
    log_step "Creating directory structure..."
    
    # Clean up any existing deployment
    if [ -d "$BASE_DIR" ]; then
        log_warn "Existing deployment found at $BASE_DIR"
        read -p "Remove and start fresh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing deployment..."
            rm -rf "$BASE_DIR"
        else
            log_error "Deployment cancelled. Remove $BASE_DIR manually if needed."
            exit 1
        fi
    fi
    
    mkdir -p "$BASE_DIR"
    mkdir -p "$SCRIPTS_DIR"
    
    log_info "Directory structure created at $BASE_DIR"
}

download_polygon_edge() {
    log_step "Downloading Polygon Edge v$POLYGON_EDGE_VERSION..."
    
    cd "$BASE_DIR"
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Convert architecture to Polygon Edge naming
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    BINARY_NAME="polygon-edge_${POLYGON_EDGE_VERSION}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/0xPolygon/polygon-edge/releases/download/v${POLYGON_EDGE_VERSION}/${BINARY_NAME}"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    
    if command -v wget &> /dev/null; then
        wget -q "$DOWNLOAD_URL" -O polygon-edge.tar.gz
    elif command -v curl &> /dev/null; then
        curl -sL "$DOWNLOAD_URL" -o polygon-edge.tar.gz
    else
        log_error "Neither wget nor curl is installed"
        exit 1
    fi
    
    tar -xzf polygon-edge.tar.gz
    chmod +x polygon-edge
    rm polygon-edge.tar.gz
    
    log_info "✅ Polygon Edge v$POLYGON_EDGE_VERSION downloaded"
}

generate_validator_secrets() {
    log_step "Generating validator secrets for $NUM_VALIDATORS nodes..."
    
    cd "$BASE_DIR"
    
    for i in $(seq 1 $NUM_VALIDATORS); do
        log_info "Generating secrets for node$i..."
        ./polygon-edge secrets init --data-dir "test-chain-$i" --insecure
    done
    
    log_info "✅ All validator secrets generated"
}

collect_validator_info() {
    log_step "Collecting validator information..."
    
    cd "$BASE_DIR"
    
    # Arrays to store validator info
    declare -a VALIDATORS
    declare -a NODE_IDS
    
    for i in $(seq 1 $NUM_VALIDATORS); do
        log_info "Reading validator info for node$i..."
        
        # Get validator address and BLS key
        OUTPUT=$(./polygon-edge secrets output --data-dir "test-chain-$i")
        
        # Extract address (without 0x prefix for genesis)
        ADDRESS=$(echo "$OUTPUT" | grep "Public key (address)" | awk '{print $NF}')
        ADDRESS_NO_PREFIX=${ADDRESS#0x}
        
        # Extract BLS public key
        BLS_KEY=$(echo "$OUTPUT" | grep "BLS Public key" | awk '{print $NF}')
        
        # Extract Node ID for bootnode
        NODE_ID=$(echo "$OUTPUT" | grep "Node ID" | awk '{print $NF}')
        
        # Store validator in format: ADDRESS:BLS_KEY
        VALIDATORS+=("${ADDRESS_NO_PREFIX}:${BLS_KEY}")
        NODE_IDS+=("$NODE_ID")
        
        log_info "  Address: $ADDRESS"
        log_info "  BLS Key: $BLS_KEY"
        log_info "  Node ID: $NODE_ID"
    done
    
    # Export for use in genesis generation
    export VAL1="${VALIDATORS[0]}"
    export VAL2="${VALIDATORS[1]}"
    export VAL3="${VALIDATORS[2]}"
    export VAL4="${VALIDATORS[3]}"
    export BOOTNODE_ID="${NODE_IDS[0]}"
    
    log_info "✅ Validator information collected"
}

generate_genesis() {
    log_step "Generating genesis configuration..."
    
    cd "$BASE_DIR"
    
    # Use dns4 bootnode for Docker networking
    BOOTNODE="/dns4/node1/tcp/1478/p2p/$BOOTNODE_ID"
    
    log_info "Bootnode: $BOOTNODE"
    log_info "Validators: $NUM_VALIDATORS"
    
    ./polygon-edge genesis \
        --consensus ibft \
        --ibft-validator "$VAL1" \
        --ibft-validator "$VAL2" \
        --ibft-validator "$VAL3" \
        --ibft-validator "$VAL4" \
        --bootnode "$BOOTNODE" \
        --premine 0x85da99c8a7c2c95964c8efd687e95e632fc423a6:1000000000000000000000 \
        --block-gas-limit 10000000 \
        --chain-id $CHAIN_ID
    
    log_info "✅ Genesis configuration generated"
    
    # Show bootnode config
    log_info "Verifying bootnode configuration..."
    if command -v jq &> /dev/null; then
        echo "Bootnodes:"
        cat genesis.json | jq '.bootnodes'
    fi
}

create_docker_compose() {
    log_step "Creating Docker Compose configuration..."
    
    cd "$BASE_DIR"
    
    cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  node1:
    image: 0xpolygon/polygon-edge:1.3.1
    user: root
    command:
      - server
      - --data-dir=/data
      - --chain=/genesis.json
      - --jsonrpc=0.0.0.0:8545
      - --libp2p=0.0.0.0:1478
      - --seal
    container_name: node1
    volumes:
      - ./test-chain-1:/data
      - ./genesis.json:/genesis.json:ro
    ports:
      - "8545:8545"
    networks:
      - edge-network

  node2:
    image: 0xpolygon/polygon-edge:1.3.1
    user: root
    command:
      - server
      - --data-dir=/data
      - --chain=/genesis.json
      - --libp2p=0.0.0.0:1478
      - --jsonrpc=127.0.0.1:8545
      - --seal
    container_name: node2
    volumes:
      - ./test-chain-2:/data
      - ./genesis.json:/genesis.json:ro
    networks:
      - edge-network

  node3:
    image: 0xpolygon/polygon-edge:1.3.1
    user: root
    command:
      - server
      - --data-dir=/data
      - --chain=/genesis.json
      - --libp2p=0.0.0.0:1478
      - --jsonrpc=127.0.0.1:8545
      - --seal
    container_name: node3
    volumes:
      - ./test-chain-3:/data
      - ./genesis.json:/genesis.json:ro
    networks:
      - edge-network

  node4:
    image: 0xpolygon/polygon-edge:1.3.1
    user: root
    command:
      - server
      - --data-dir=/data
      - --chain=/genesis.json
      - --libp2p=0.0.0.0:1478
      - --jsonrpc=127.0.0.1:8545
      - --seal
    container_name: node4
    volumes:
      - ./test-chain-4:/data
      - ./genesis.json:/genesis.json:ro
    networks:
      - edge-network

networks:
  edge-network:
    driver: bridge
EOF
    
    log_info "✅ Docker Compose configuration created"
}

pull_docker_images() {
    log_step "Pre-downloading Docker images..."
    
    log_info "Pulling Polygon Edge v$POLYGON_EDGE_VERSION (this may take a few minutes)..."
    if docker pull 0xpolygon/polygon-edge:$POLYGON_EDGE_VERSION; then
        log_info "✅ Polygon Edge v$POLYGON_EDGE_VERSION image downloaded"
    else
        log_error "Failed to pull Polygon Edge image"
        exit 1
    fi
}

create_management_scripts() {
    log_step "Creating management scripts..."
    
    # Start script
    cat > "$BASE_DIR/start.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting CrowdfundChain Polygon Edge Network..."
docker-compose up -d
echo "✅ Network started"
echo ""
echo "Monitor with: ./monitor.sh"
echo "View logs with: ./logs.sh"
EOF
    chmod +x "$BASE_DIR/start.sh"
    
    # Stop script
    cat > "$BASE_DIR/stop.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🛑 Stopping CrowdfundChain Polygon Edge Network..."
docker-compose down
echo "✅ Network stopped"
EOF
    chmod +x "$BASE_DIR/stop.sh"
    
    # Monitor script
    cat > "$BASE_DIR/monitor.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "=== CrowdfundChain Polygon Edge Network Status ==="
echo ""

echo "📦 Container Status:"
docker-compose ps
echo ""

echo "🔗 Blockchain Status:"
BLOCK=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
    grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$BLOCK" ] && [ "$BLOCK" != "0x" ]; then
    BLOCK_DEC=$((BLOCK))
    echo "  ✅ Current Block: $BLOCK_DEC"
    echo "  ✅ RPC Endpoint: http://localhost:8545"
    echo "  ✅ Chain ID: 100"
else
    echo "  ⏳ Network starting up..."
fi

echo ""
echo "🌐 Network Info:"
docker logs node1 2>&1 | grep -i "peer connected" | tail -3

echo ""
echo "💡 Commands:"
echo "  ./logs.sh        - View logs"
echo "  ./stop.sh        - Stop network"
echo "  ./restart.sh     - Restart network"
EOF
    chmod +x "$BASE_DIR/monitor.sh"
    
    # Logs script
    cat > "$BASE_DIR/logs.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

if [ -z "$1" ]; then
    echo "📋 Showing logs for all nodes (following)..."
    docker-compose logs -f
else
    echo "📋 Showing logs for $1..."
    docker logs -f "$1"
fi
EOF
    chmod +x "$BASE_DIR/logs.sh"
    
    # Restart script
    cat > "$BASE_DIR/restart.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🔄 Restarting CrowdfundChain Polygon Edge Network..."
docker-compose down
sleep 2
docker-compose up -d
echo "✅ Network restarted"
echo ""
./monitor.sh
EOF
    chmod +x "$BASE_DIR/restart.sh"
    
    log_info "✅ Management scripts created"
}

create_readme() {
    log_step "Creating deployment README..."
    
    cat > "$BASE_DIR/README.md" <<'EOF'
# CrowdfundChain Polygon Edge Network

## 🎉 Deployment Complete!

Your 4-node Polygon Edge IBFT validator network is ready.

## 📊 Network Configuration

- **Network**: Private Polygon Edge
- **Consensus**: IBFT (Istanbul Byzantine Fault Tolerance)
- **Validators**: 4 nodes
- **Chain ID**: 100
- **Block Time**: 2 seconds
- **RPC Endpoint**: http://localhost:8545 (or your VPS IP)

## 🚀 Quick Start

```bash
# Start the network
./start.sh

# Monitor status
./monitor.sh

# View logs
./logs.sh

# Stop network
./stop.sh

# Restart network
./restart.sh
```

## 📡 RPC Endpoint

Connect your applications to:
- **Local**: http://localhost:8545
- **External**: http://YOUR_VPS_IP:8545

## 🔑 Validator Information

Validator secrets are stored in:
- `test-chain-1/` - Node 1 (Bootnode)
- `test-chain-2/` - Node 2
- `test-chain-3/` - Node 3
- `test-chain-4/` - Node 4

## 🧪 Testing the Network

```bash
# Check block height
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check network ID
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'
```

## 🔧 Troubleshooting

**Network not starting?**
```bash
docker-compose logs
```

**Nodes not connecting?**
```bash
# Check bootnode
docker logs node1 | grep "LibP2P"

# Check peer connections
docker logs node2 | grep "peer"
```

**Reset network?**
```bash
./stop.sh
rm -rf test-chain-*/blockchain
./start.sh
```

## 📚 Additional Resources

- [Polygon Edge Documentation](https://docs.polygon.technology/docs/edge/overview/)
- [IBFT Consensus](https://docs.polygon.technology/docs/edge/consensus/ibft/)

## 🎯 Integration with CrowdfundChain

Update your blockchain configuration:

```typescript
// shared/blockchain-config.ts
export const BLOCKCHAIN_NETWORKS = {
  local: {
    rpcUrl: 'http://localhost:8545',
    chainId: 100,
    name: 'CrowdfundChain Local'
  },
  production: {
    rpcUrl: 'http://YOUR_VPS_IP:8545',
    chainId: 100,
    name: 'CrowdfundChain Production'
  }
};
```

---
Generated by polygon-deploy.sh
EOF
    
    log_info "✅ README created"
}

# Main deployment flow
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  CrowdfundChain Africa - Polygon Edge Deployment              ║"
    echo "║  4-Node IBFT Validator Network                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_environment
    check_dependencies
    create_directories
    download_polygon_edge
    pull_docker_images
    generate_validator_secrets
    collect_validator_info
    generate_genesis
    create_docker_compose
    create_management_scripts
    create_readme
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ DEPLOYMENT COMPLETE!                                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Network files created in: $BASE_DIR"
    echo ""
    log_step "Next Steps:"
    echo "  1. cd polygon-edge"
    echo "  2. ./start.sh              # Start the network"
    echo "  3. ./monitor.sh            # Check status"
    echo ""
    log_warn "First startup may take 30-60 seconds for nodes to connect"
    echo ""
}

# Run main function
main
