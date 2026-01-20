#!/bin/bash

################################################################################
# CrowdfundChain - Complete Deployment Script
# 
# This script deploys EVERYTHING:
#   1. Polygon Edge 4-node blockchain network
#   2. PostgreSQL database
#   3. Redis cache/queue
#   4. Keycloak SSO server
#   5. (Optional) Django application
#   6. Smart contract deployment
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }
log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Parse arguments
MODE="infrastructure"  # infrastructure, full, deploy-only
SKIP_BLOCKCHAIN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            MODE="full"
            shift
            ;;
        --infrastructure-only)
            MODE="infrastructure"
            shift
            ;;
        --deploy-contracts-only)
            MODE="deploy-only"
            shift
            ;;
        --skip-blockchain)
            SKIP_BLOCKCHAIN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full                   Start everything including Django/Celery"
            echo "  --infrastructure-only    Start blockchain + database services only (default)"
            echo "  --deploy-contracts-only  Only deploy smart contracts"
            echo "  --skip-blockchain        Skip Polygon Edge nodes (use existing network)"
            echo "  --help                   Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Start infrastructure (blockchain + databases)"
            echo "  $0 --full                    # Start everything including Django"
            echo "  $0 --skip-blockchain         # Use existing blockchain, start databases"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       CrowdfundChain - Complete Infrastructure Deployment     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Configuration:"
echo "  Mode: $MODE"
echo "  Skip Blockchain: $SKIP_BLOCKCHAIN"
echo ""

#######################
# STEP 1: Prerequisites
#######################
log_section "Step 1: Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo "Install: curl -fsSL https://get.docker.com | sh"
    exit 1
fi
log_info "Docker: $(docker --version | cut -d' ' -f3)"

# Check Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    log_error "Docker Compose is not installed"
    exit 1
fi
log_info "Docker Compose found"

# Check Docker daemon access
if ! docker ps &> /dev/null; then
    log_error "Cannot access Docker. Add user to docker group or use sudo"
    exit 1
fi
log_info "Docker daemon accessible"

#######################
# STEP 2: Environment Setup
#######################
log_section "Step 2: Setting Up Environment"

if [ ! -f ".env" ]; then
    log_step "Creating .env from template..."
    
    if [ -f ".env.complete.example" ]; then
        cp .env.complete.example .env
    else
        log_error ".env.complete.example not found"
        exit 1
    fi
    
    # Generate secure passwords (alphanumeric only to avoid sed issues)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)
    REDIS_PASSWORD=$(openssl rand -hex 16)
    KEYCLOAK_DB_PASSWORD=$(openssl rand -hex 16)
    KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 16)
    DJANGO_SECRET_KEY=$(openssl rand -hex 32)
    
    # Update .env with secure passwords using | as delimiter to avoid issues
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env
    sed -i "s|KEYCLOAK_DB_PASSWORD=.*|KEYCLOAK_DB_PASSWORD=$KEYCLOAK_DB_PASSWORD|" .env
    sed -i "s|KEYCLOAK_ADMIN_PASSWORD=.*|KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD|" .env
    sed -i "s|DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY|" .env
    
    log_info "Generated secure passwords"
    log_warn "SAVE THESE CREDENTIALS from .env file!"
else
    log_info ".env already exists"
fi

# Source environment
set -a
source .env
set +a

#######################
# STEP 3: Start Services
#######################
log_section "Step 3: Starting Docker Services"

# Use infrastructure-only file by default (no build services)
COMPOSE_FILE="docker-compose.infrastructure.yml"
FULL_COMPOSE_FILE="docker-compose.complete.yml"
VPS_COMPOSE_FILE="docker-compose.vps.yml"

# Create networks if they don't exist
log_step "Ensuring Docker networks exist..."
docker network create crowdfunding_polygon_network 2>/dev/null || true
docker network create crowdfunding_crowdfund_network 2>/dev/null || true

if [ "$MODE" = "deploy-only" ]; then
    log_step "Running contract deployment only..."
    $COMPOSE_CMD -f $FULL_COMPOSE_FILE --profile deploy up contract-deployer
    log_info "Contract deployment complete"
    exit 0
fi

# Stop conflicting containers
log_step "Stopping any conflicting containers..."
docker stop crowdfundchain_postgres crowdfundchain_redis crowdfundchain_keycloak 2>/dev/null || true
docker rm crowdfundchain_postgres crowdfundchain_redis crowdfundchain_keycloak 2>/dev/null || true

# Pull images
log_step "Pulling Docker images..."
$COMPOSE_CMD -f $VPS_COMPOSE_FILE pull 2>/dev/null || true

if [ "$SKIP_BLOCKCHAIN" = true ]; then
    log_step "Starting database services only (skipping blockchain)..."
    $COMPOSE_CMD -f $VPS_COMPOSE_FILE up -d postgres redis postgres_keycloak keycloak
else
    # Setup and start Polygon Edge blockchain
    BLOCKCHAIN_COMPOSE="docker-compose.blockchain.yml"
    
    if [ -f "$BLOCKCHAIN_COMPOSE" ]; then
        # Check if validators are initialized
        if [ ! -d "polygon-edge/validators/validator1" ] || [ ! -f "polygon-edge/genesis/genesis.json" ]; then
            log_step "Initializing Polygon Edge network..."
            if [ -f "scripts/setup-polygon-edge.sh" ]; then
                chmod +x scripts/setup-polygon-edge.sh
                ./scripts/setup-polygon-edge.sh
            else
                log_warn "setup-polygon-edge.sh not found, skipping blockchain initialization"
            fi
        else
            log_info "Polygon Edge already initialized"
        fi
        
        # Start blockchain nodes
        log_step "Starting Polygon Edge blockchain nodes..."
        $COMPOSE_CMD -f $BLOCKCHAIN_COMPOSE up -d
    else
        log_warn "docker-compose.blockchain.yml not found, skipping blockchain"
    fi
    
    log_step "Starting all infrastructure services..."
    if [ "$MODE" = "full" ]; then
        # Full mode - start infrastructure first, then build Django
        log_step "Starting infrastructure services..."
        $COMPOSE_CMD -f $VPS_COMPOSE_FILE up -d postgres redis postgres_keycloak keycloak
        
        log_step "Building and starting Django application..."
        $COMPOSE_CMD -f $VPS_COMPOSE_FILE --profile full up -d --build django celery_worker celery_beat
    else
        # Infrastructure only - use VPS file
        $COMPOSE_CMD -f $VPS_COMPOSE_FILE up -d postgres redis postgres_keycloak keycloak
    fi
fi

log_info "Docker containers started"

#######################
# STEP 4: Wait for Health
#######################
log_section "Step 4: Waiting for Services"

wait_for_service() {
    local service=$1
    local check_cmd=$2
    local timeout=${3:-60}
    local elapsed=0
    
    echo -n "  Waiting for $service..."
    while ! eval "$check_cmd" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            echo " TIMEOUT"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    echo " Ready!"
    return 0
}

# Wait for PostgreSQL
wait_for_service "PostgreSQL" \
    "$COMPOSE_CMD -f $VPS_COMPOSE_FILE exec -T postgres pg_isready -U ${POSTGRES_USER:-dltadmin} -d ${POSTGRES_DB:-crowdfundchain_db}"
log_info "PostgreSQL is ready"

# Wait for Redis
wait_for_service "Redis" \
    "$COMPOSE_CMD -f $VPS_COMPOSE_FILE exec -T redis redis-cli -a '${REDIS_PASSWORD:-CrowdfundRedis2025!}' ping"
log_info "Redis is ready"

# Wait for Keycloak (longer timeout)
wait_for_service "Keycloak" \
    "curl -sf http://localhost:${KEYCLOAK_PORT:-8080}/health/ready" 120 || log_warn "Keycloak still starting..."
log_info "Keycloak is starting"

if [ "$SKIP_BLOCKCHAIN" != true ]; then
    # Wait for blockchain (only if nodes are expected)
    if docker ps | grep -q polygon-edge; then
        wait_for_service "Blockchain Node 1" \
            "curl -sf -X POST http://localhost:8545 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'" 90
        log_info "Blockchain is ready"
    else
        log_warn "Polygon Edge nodes not running, skipping blockchain check"
    fi
fi

#######################
# STEP 5: Deploy Contracts
#######################
if [ "$SKIP_BLOCKCHAIN" != true ]; then
    log_section "Step 5: Deploying Smart Contracts"
    
    # Check if contracts already deployed
    DEPLOYMENT_FILE="smart-contracts/deployments/localhost.json"
    
    if [ -f "$DEPLOYMENT_FILE" ]; then
        log_warn "Contracts already deployed, checking..."
        
        FACTORY=$(jq -r '.contracts.campaignFactory.address // empty' "$DEPLOYMENT_FILE" 2>/dev/null)
        if [ ! -z "$FACTORY" ]; then
            log_info "Campaign Factory: $FACTORY"
            # Update .env with contract addresses
            NFT=$(jq -r '.contracts.nftShareCertificate.address' "$DEPLOYMENT_FILE")
            DAO=$(jq -r '.contracts.daoGovernance.address' "$DEPLOYMENT_FILE")
            IMPL=$(jq -r '.contracts.campaignImplementation.address' "$DEPLOYMENT_FILE")
            
            sed -i "s/CONTRACT_NFT_CERTIFICATE=.*/CONTRACT_NFT_CERTIFICATE=$NFT/" .env
            sed -i "s/CONTRACT_DAO_GOVERNANCE=.*/CONTRACT_DAO_GOVERNANCE=$DAO/" .env
            sed -i "s/CONTRACT_CAMPAIGN_FACTORY=.*/CONTRACT_CAMPAIGN_FACTORY=$FACTORY/" .env
            sed -i "s/CONTRACT_CAMPAIGN_IMPLEMENTATION=.*/CONTRACT_CAMPAIGN_IMPLEMENTATION=$IMPL/" .env
            
            log_info "Contract addresses updated in .env"
        fi
    else
        # Check if contract-deployer service exists
        if $COMPOSE_CMD -f $VPS_COMPOSE_FILE config --services 2>/dev/null | grep -q contract-deployer; then
            log_step "Deploying smart contracts..."
            $COMPOSE_CMD -f $VPS_COMPOSE_FILE --profile deploy up contract-deployer
            
            if [ -f "$DEPLOYMENT_FILE" ]; then
                # Update .env with new addresses
                NFT=$(jq -r '.contracts.nftShareCertificate.address' "$DEPLOYMENT_FILE")
                DAO=$(jq -r '.contracts.daoGovernance.address' "$DEPLOYMENT_FILE")
                FACTORY=$(jq -r '.contracts.campaignFactory.address' "$DEPLOYMENT_FILE")
                IMPL=$(jq -r '.contracts.campaignImplementation.address' "$DEPLOYMENT_FILE")
                
                sed -i "s/CONTRACT_NFT_CERTIFICATE=.*/CONTRACT_NFT_CERTIFICATE=$NFT/" .env
                sed -i "s/CONTRACT_DAO_GOVERNANCE=.*/CONTRACT_DAO_GOVERNANCE=$DAO/" .env
                sed -i "s/CONTRACT_CAMPAIGN_FACTORY=.*/CONTRACT_CAMPAIGN_FACTORY=$FACTORY/" .env
                sed -i "s/CONTRACT_CAMPAIGN_IMPLEMENTATION=.*/CONTRACT_CAMPAIGN_IMPLEMENTATION=$IMPL/" .env
                
                log_info "Contracts deployed and .env updated"
            fi
        else
            log_warn "contract-deployer service not found, skipping smart contract deployment"
            log_info "Deploy contracts manually: cd smart-contracts && npx hardhat run scripts/deploy.js"
        fi
    fi
fi

#######################
# STEP 6: Build and Deploy Frontend
#######################
log_section "Step 6: Deploying React Frontend"

FRONTEND_DIR="/var/www/crowdfundchain/frontend"
mkdir -p $FRONTEND_DIR

# Check for pre-built frontend archive (transferred from Repo)
if [ -f "frontend-build.tar.gz" ]; then
    log_step "Found pre-built frontend archive, extracting..."
    rm -rf $FRONTEND_DIR/*
    tar -xzf frontend-build.tar.gz -C $FRONTEND_DIR/
    chown -R www-data:www-data $FRONTEND_DIR 2>/dev/null || true
    chmod -R 755 $FRONTEND_DIR
    log_info "Frontend deployed from archive to $FRONTEND_DIR"
elif [ -d "dist/public" ]; then
    log_step "Found pre-built frontend in dist/public, deploying..."
    rm -rf $FRONTEND_DIR/*
    cp -r dist/public/* $FRONTEND_DIR/
    chown -R www-data:www-data $FRONTEND_DIR 2>/dev/null || true
    chmod -R 755 $FRONTEND_DIR
    log_info "Frontend deployed to $FRONTEND_DIR"
elif command -v npm &> /dev/null && [ -d "client" ]; then
    log_step "Building React frontend with npm..."
    
    # Create production env if not exists
    if [ ! -f "client/.env.production" ]; then
        cat > client/.env.production << EOF
VITE_API_BASE_URL=http://$(hostname -I | awk '{print $1}')
VITE_KEYCLOAK_URL=http://$(hostname -I | awk '{print $1}'):8080/auth/
VITE_KEYCLOAK_REALM=crowdfundchain
VITE_KEYCLOAK_CLIENT_ID=crowdfundchain-frontend
EOF
    fi
    
    npm run build 2>/dev/null || {
        log_warn "npm run build failed, trying with npm install first..."
        npm install && npm run build
    }
    
    if [ -d "dist/public" ]; then
        rm -rf $FRONTEND_DIR/*
        cp -r dist/public/* $FRONTEND_DIR/
        chown -R www-data:www-data $FRONTEND_DIR 2>/dev/null || true
        chmod -R 755 $FRONTEND_DIR
        log_info "Frontend built and deployed to $FRONTEND_DIR"
    fi
else
    log_warn "No frontend found. Creating placeholder..."
    cat > $FRONTEND_DIR/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>CrowdfundChain Africa</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; text-align: center; padding: 50px; background: linear-gradient(135deg, #1e3a5f 0%, #0d1b2a 100%); color: white; min-height: 100vh; margin: 0; }
        h1 { color: #60a5fa; font-size: 2.5rem; margin-bottom: 0.5rem; }
        .subtitle { color: #94a3b8; font-size: 1.2rem; margin-bottom: 2rem; }
        .links { margin-top: 30px; }
        a { display: inline-block; margin: 10px; padding: 12px 24px; background: #2563eb; color: white; text-decoration: none; border-radius: 8px; font-weight: 500; transition: background 0.2s; }
        a:hover { background: #1d4ed8; }
        .note { margin-top: 40px; color: #64748b; font-size: 0.9rem; }
    </style>
</head>
<body>
    <h1>CrowdfundChain Africa</h1>
    <p class="subtitle">Blockchain-powered crowdfunding for African SMEs</p>
    <div class="links">
        <a href="/api/docs/">API Documentation</a>
        <a href="/admin/">Admin Panel</a>
        <a href="/api/health/">Health Check</a>
    </div>
    <p class="note">Full React frontend coming soon. Upload frontend-build.tar.gz and restart deployment.</p>
</body>
</html>
HTML
    log_info "Placeholder frontend created"
    log_warn "Upload frontend-build.tar.gz from Repo to deploy full frontend"
fi

#######################
# STEP 7: Django Migrations
#######################
log_section "Step 7: Running Django Migrations"

if [ -d "django-issuer-platform" ]; then
    log_step "Setting up Django..."
    
    cd django-issuer-platform
    
    # Create venv if needed
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    pip install -q -r requirements.txt
    
    # Set database URL
    export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
    
    # Run migrations
    python manage.py migrate
    log_info "Django migrations complete"
    
    deactivate
    cd ..
else
    log_warn "django-issuer-platform not found, skipping migrations"
fi

#######################
# STEP 8: Verification
#######################
log_section "Step 8: Verification"

if [ -f "./verify-dual-ledger-vps.sh" ]; then
    chmod +x ./verify-dual-ledger-vps.sh
    ./verify-dual-ledger-vps.sh
else
    # Quick verification
    echo "Service Status:"
    $COMPOSE_CMD -f $VPS_COMPOSE_FILE ps
fi

#######################
# FINAL OUTPUT
#######################
log_section "✅ Deployment Complete!"

PUBLIC_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "📊 Service Access:"
echo "─────────────────────────────────────────"
echo "Frontend:           http://$PUBLIC_IP/"
echo "API Docs:           http://$PUBLIC_IP/api/docs/"
echo "Django Admin:       http://$PUBLIC_IP/admin/"
echo "Keycloak Admin:     http://$PUBLIC_IP:8080/admin"
echo "Blockchain RPC:     http://localhost:8545"
echo "PostgreSQL:         localhost:${POSTGRES_PORT:-5432}"
echo "Redis:              localhost:${REDIS_PORT:-6379}"
if [ "$MODE" = "full" ]; then
    echo "Django API:         http://localhost:${DJANGO_PORT:-8000}"
fi
echo ""
echo "🔑 Credentials (saved in .env):"
echo "─────────────────────────────────────────"
echo "PostgreSQL User:    $POSTGRES_USER"
echo "Keycloak Admin:     ${KEYCLOAK_ADMIN:-admin}"
echo ""
echo "📋 Manage Services:"
echo "─────────────────────────────────────────"
echo "View status:  $COMPOSE_CMD -f $VPS_COMPOSE_FILE ps"
echo "View logs:    $COMPOSE_CMD -f $VPS_COMPOSE_FILE logs -f"
echo "Stop all:     $COMPOSE_CMD -f $VPS_COMPOSE_FILE down"
echo "Restart:      $COMPOSE_CMD -f $VPS_COMPOSE_FILE restart"
echo ""
if [ "$MODE" != "full" ]; then
    echo "🚀 Start Django manually:"
    echo "─────────────────────────────────────────"
    echo "cd django-issuer-platform"
    echo "source venv/bin/activate"
    echo "python manage.py runserver 0.0.0.0:8000"
    echo ""
    echo "Or start full stack:"
    echo "$0 --full"
fi
echo ""
log_info "CrowdfundChain is ready! 🎉"
