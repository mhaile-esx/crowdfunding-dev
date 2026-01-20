#!/bin/bash

################################################################################
# CrowdfundChain - Pre-Deployment Validation Script
# Validates all prerequisites before deploying Polygon network
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

check_pass() {
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

echo "=================================="
echo "🔍 CrowdfundChain Deployment Validation"
echo "=================================="
echo ""

#######################
# 1. SYSTEM CHECKS
#######################
log_step "Running system checks..."
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check OS
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    log_info "Operating System: $OSTYPE"
    check_pass
else
    log_warn "Unsupported OS: $OSTYPE (may have issues)"
fi

# Check available disk space
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if (( $(echo "$AVAILABLE_SPACE > 10" | bc -l) )); then
    log_info "Disk space available: ${AVAILABLE_SPACE}GB (sufficient)"
    check_pass
else
    log_error "Low disk space: ${AVAILABLE_SPACE}GB (need at least 10GB)"
fi

# Check available memory
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v free &> /dev/null; then
    AVAILABLE_RAM=$(free -g | awk 'NR==2 {print $7}')
    if [ "$AVAILABLE_RAM" -gt 2 ]; then
        log_info "Available RAM: ${AVAILABLE_RAM}GB (sufficient)"
        check_pass
    else
        log_warn "Low available RAM: ${AVAILABLE_RAM}GB (recommend 4GB+)"
    fi
else
    log_warn "Cannot check RAM (free command not available)"
fi

#######################
# 2. DOCKER CHECKS
#######################
echo ""
log_step "Checking Docker installation..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_info "Docker installed: $DOCKER_VERSION"
    check_pass
else
    log_error "Docker is NOT installed"
    log_error "Install: curl -fsSL https://get.docker.com | sh"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    log_info "Docker Compose installed: $COMPOSE_VERSION"
    check_pass
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    log_info "Docker Compose (plugin) installed: $COMPOSE_VERSION"
    check_pass
else
    log_error "Docker Compose is NOT installed"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if docker ps &> /dev/null; then
    log_info "Docker daemon is running"
    check_pass
else
    log_error "Docker daemon is NOT running or permission denied"
    log_error "Try: sudo systemctl start docker"
    log_error "Or add user to docker group: sudo usermod -aG docker $USER"
fi

#######################
# 3. PORT AVAILABILITY
#######################
echo ""
log_step "Checking port availability..."

REQUIRED_PORTS=(8545 8546 8547 8548 8549 8550 8551 8552 30303 30304 30305 30306 26656 26657 26658 26659 26660 26661 26662 26663 1317 1318 1319 1320)

for port in "${REQUIRED_PORTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_error "Port $port is already in use"
    else
        check_pass
    fi
done

log_info "Checked ${#REQUIRED_PORTS[@]} ports - available ports: $((${#REQUIRED_PORTS[@]} - FAILED_CHECKS + PASSED_CHECKS))"

#######################
# 4. NETWORK CHECKS
#######################
echo ""
log_step "Checking network connectivity..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if ping -c 1 8.8.8.8 &> /dev/null; then
    log_info "Internet connectivity: OK"
    check_pass
else
    log_error "No internet connectivity"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if curl -s https://hub.docker.com &> /dev/null; then
    log_info "Docker Hub reachable: OK"
    check_pass
else
    log_warn "Cannot reach Docker Hub (may have issues pulling images)"
fi

#######################
# 5. REQUIRED TOOLS
#######################
echo ""
log_step "Checking required tools..."

declare -A TOOLS=(
    ["curl"]="required"
    ["jq"]="recommended"
    ["bc"]="required"
    ["netstat"]="recommended"
    ["lsof"]="recommended"
)

for tool in "${!TOOLS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v $tool &> /dev/null; then
        log_info "$tool: installed"
        check_pass
    else
        if [ "${TOOLS[$tool]}" == "required" ]; then
            log_error "$tool: NOT installed (required)"
        else
            log_warn "$tool: NOT installed (recommended)"
        fi
    fi
done

#######################
# 6. NODE.JS CHECKS (for key generation)
#######################
echo ""
log_step "Checking Node.js installation..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_info "Node.js installed: $NODE_VERSION"
    check_pass
else
    log_error "Node.js is NOT installed (required for validator key generation)"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    log_info "npm installed: $NPM_VERSION"
    check_pass
else
    log_error "npm is NOT installed"
fi

#######################
# 7. DOCKER IMAGES
#######################
echo ""
log_step "Checking Docker images..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if docker images | grep -q "0xpolygon/bor"; then
    log_info "Polygon Bor image: already downloaded"
    check_pass
else
    log_warn "Polygon Bor image: not downloaded (will download during deployment)"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if docker images | grep -q "0xpolygon/heimdall"; then
    log_info "Polygon Heimdall image: already downloaded"
    check_pass
else
    log_warn "Polygon Heimdall image: not downloaded (will download during deployment)"
fi

#######################
# 8. FILE SYSTEM CHECKS
#######################
echo ""
log_step "Checking file system permissions..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -w "." ]; then
    log_info "Write permissions in current directory: OK"
    check_pass
else
    log_error "No write permissions in current directory"
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "polygon-deploy.sh" ]; then
    log_info "Deployment script found: polygon-deploy.sh"
    check_pass
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -x "polygon-deploy.sh" ]; then
        log_info "Deployment script is executable"
        check_pass
    else
        log_warn "Deployment script not executable (run: chmod +x polygon-deploy.sh)"
    fi
else
    log_error "Deployment script NOT found: polygon-deploy.sh"
fi

#######################
# 9. EXISTING DEPLOYMENT
#######################
echo ""
log_step "Checking for existing deployment..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -d "polygon-network" ]; then
    log_warn "polygon-network directory already exists"
    
    if [ -f "polygon-network/docker-compose.yml" ]; then
        log_warn "Existing docker-compose.yml found (may need cleanup)"
    fi
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if docker-compose -f polygon-network/docker-compose.yml ps 2>/dev/null | grep -q "Up"; then
        log_warn "Containers are currently running"
    else
        log_info "No running containers from previous deployment"
        check_pass
    fi
else
    log_info "No existing deployment found (clean slate)"
    check_pass
fi

#######################
# 10. DOCKER NETWORK
#######################
echo ""
log_step "Checking Docker network..."

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if docker network ls | grep -q "polygon-network"; then
    log_warn "Docker network 'polygon-network' already exists"
else
    log_info "Docker network namespace available"
    check_pass
fi

#######################
# SUMMARY
#######################
echo ""
echo "=================================="
echo "📊 Validation Summary"
echo "=================================="
echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

# Determine if ready for deployment
if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
        echo -e "${GREEN}✅ All checks passed! Ready for deployment.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ./polygon-deploy.sh"
        echo "  2. Wait for deployment to complete"
        echo "  3. Start network: cd polygon-network && ./start.sh"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Some warnings detected but deployment can proceed.${NC}"
        echo ""
        echo "Recommendations:"
        echo "  - Install missing recommended tools: jq, netstat, lsof"
        echo "  - Free up disk space if running low"
        echo "  - Review warnings above"
        echo ""
        echo "Proceed with deployment? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Proceeding with deployment..."
            exit 0
        else
            echo "Deployment cancelled."
            exit 1
        fi
    fi
else
    echo -e "${RED}❌ Critical issues detected! Cannot proceed with deployment.${NC}"
    echo ""
    echo "Please fix the following:"
    echo ""
    
    # List critical issues
    if ! command -v docker &> /dev/null; then
        echo "  1. Install Docker: curl -fsSL https://get.docker.com | sh"
    fi
    
    if ! docker ps &> /dev/null; then
        echo "  2. Start Docker daemon: sudo systemctl start docker"
        echo "     Or add user to docker group: sudo usermod -aG docker $USER"
    fi
    
    if ! command -v node &> /dev/null; then
        echo "  3. Install Node.js: https://nodejs.org/"
    fi
    
    echo ""
    echo "After fixing issues, run this validation script again."
    exit 1
fi
