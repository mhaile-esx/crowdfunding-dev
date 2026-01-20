#!/bin/bash

################################################################################
# CrowdfundChain - Blockchain Network Starter (ESX-Compatible)
# Uses Hardhat Network instead of Docker-based Polygon
################################################################################

GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "🔗 CrowdfundChain Blockchain Network"
echo "========================================"
echo ""

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Check if Hardhat is available
if ! command -v npx &> /dev/null; then
    echo "Error: npx is not installed"
    exit 1
fi

log_step "Starting Hardhat Network (Ethereum-compatible blockchain)..."
echo ""
log_info "Network Details:"
echo "  • Network: Hardhat Local"
echo "  • Chain ID: 31337"
echo "  • RPC URL: http://localhost:8545"
echo "  • WebSocket: ws://localhost:8545"
echo "  • Block Time: ~2 seconds"
echo "  • Pre-funded Accounts: 20 accounts with 10,000 ETH each"
echo ""
log_step "Starting blockchain..."
echo ""
log_warn "Note: This replaces the Polygon local network (which requires Docker)"
log_info "All your smart contracts will work exactly the same!"
echo ""

# Start Hardhat network
npx hardhat node --hostname 0.0.0.0
