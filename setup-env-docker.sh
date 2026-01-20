#!/bin/bash

################################################################################
# CrowdfundChain - Docker Infrastructure Setup Script
# 
# This script:
# 1. Checks Docker installation
# 2. Creates necessary directories
# 3. Starts PostgreSQL, Redis, and Keycloak via Docker Compose
# 4. Waits for services to be healthy
# 5. Runs setup-env.sh to deploy contracts and configure .env
# 6. Runs Django migrations
# 7. Verifies dual-ledger pattern
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Parse arguments
MODE="services"  # services, full
SKIP_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            MODE="full"
            shift
            ;;
        --services-only)
            MODE="services"
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full             Start all services including Django and Celery"
            echo "  --services-only    Start only PostgreSQL, Redis, and Keycloak (default)"
            echo "  --skip-deploy      Skip smart contract deployment"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Start infrastructure services only"
            echo "  $0 --full                    # Start everything including Django"
            echo "  $0 --services-only           # Just PostgreSQL, Redis, Keycloak"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_section "CrowdfundChain Docker Infrastructure Setup"

echo "Configuration:"
echo "  Mode: $MODE"
echo "  Skip Deploy: $SKIP_DEPLOY"
echo ""

#######################
# STEP 1: Check Prerequisites
#######################
log_section "Step 1: Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo "Install Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi
log_info "Docker found: $(docker --version)"

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi
log_info "Docker Compose found"

# Check if running as root or in docker group
if ! docker ps &> /dev/null; then
    log_warn "Cannot access Docker daemon. You may need to:"
    echo "  1. Add user to docker group: sudo usermod -aG docker \$USER"
    echo "  2. Log out and back in, or run: newgrp docker"
    echo "  3. Or run this script with sudo"
    exit 1
fi

#######################
# STEP 2: Create Directories
#######################
log_section "Step 2: Creating Directories"

DIRS=(
    "/var/lib/crowdfundchain/postgres"
    "/var/lib/crowdfundchain/keycloak_db"
)

for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log_step "Creating $dir..."
        sudo mkdir -p "$dir"
        sudo chown -R $(whoami):$(whoami) "$dir"
        log_info "Created $dir"
    else
        log_info "$dir already exists"
    fi
done

#######################
# STEP 3: Setup Environment File
#######################
log_section "Step 3: Setting up Environment Variables"

if [ ! -f ".env.docker" ]; then
    log_step "Creating .env.docker from example..."
    cp .env.docker.example .env.docker
    
    # Generate secure passwords (hex only - safe for sed and all commands)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)
    REDIS_PASSWORD=$(openssl rand -hex 16)
    KEYCLOAK_DB_PASSWORD=$(openssl rand -hex 16)
    KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 16)
    DJANGO_SECRET_KEY=$(openssl rand -hex 32)
    
    # Update .env.docker with generated passwords (using | as delimiter)
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.docker
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env.docker
    sed -i "s|KEYCLOAK_DB_PASSWORD=.*|KEYCLOAK_DB_PASSWORD=$KEYCLOAK_DB_PASSWORD|" .env.docker
    sed -i "s|KEYCLOAK_ADMIN_PASSWORD=.*|KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD|" .env.docker
    sed -i "s|DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY|" .env.docker
    
    log_info "Generated secure passwords in .env.docker"
    log_warn "IMPORTANT: Save these credentials securely!"
else
    log_info ".env.docker already exists"
fi

# Source environment variables
set -a
source .env.docker
set +a

#######################
# STEP 4: Start Docker Services
#######################
log_section "Step 4: Starting Docker Services"

log_step "Pulling Docker images..."
docker-compose -f docker-compose.vps.yml pull

if [ "$MODE" = "full" ]; then
    log_step "Starting all services (full mode)..."
    docker-compose -f docker-compose.vps.yml --profile full up -d
else
    log_step "Starting infrastructure services only..."
    docker-compose -f docker-compose.vps.yml up -d postgres redis postgres_keycloak keycloak
fi

log_info "Docker services started"

#######################
# STEP 5: Wait for Services to be Healthy
#######################
log_section "Step 5: Waiting for Services to be Ready"

log_step "Waiting for PostgreSQL..."
timeout=60
elapsed=0
while ! docker-compose -f docker-compose.vps.yml exec -T postgres pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} &> /dev/null; do
    if [ $elapsed -ge $timeout ]; then
        log_error "PostgreSQL did not become ready in time"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done
echo ""
log_info "PostgreSQL is ready"

log_step "Waiting for Redis..."
elapsed=0
while ! docker-compose -f docker-compose.vps.yml exec -T redis redis-cli --raw incr ping &> /dev/null; do
    if [ $elapsed -ge $timeout ]; then
        log_error "Redis did not become ready in time"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done
echo ""
log_info "Redis is ready"

log_step "Waiting for Keycloak..."
timeout=120
elapsed=0
while ! curl -sf http://localhost:${KEYCLOAK_PORT:-8080}/health/ready &> /dev/null; do
    if [ $elapsed -ge $timeout ]; then
        log_warn "Keycloak did not become ready in time (this is normal on first start)"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
done
echo ""
log_info "Keycloak is starting (may take a few more minutes on first run)"

#######################
# STEP 6: Run setup-env.sh
#######################
if [ "$SKIP_DEPLOY" = false ]; then
    log_section "Step 6: Deploying Smart Contracts & Creating .env"
    
    if [ -f "./setup-env.sh" ]; then
        log_step "Running setup-env.sh..."
        ./setup-env.sh --network localhost --rpc-url http://172.18.0.5:8545
        log_info "Smart contracts deployed and .env created"
    else
        log_warn "se]tup-env.sh not found, skipping contract deployment"
    fi
else
    log_section "Step 6: Skipping Contract Deployment"
fi

#######################
# STEP 7: Run Django Migrations
#######################
log_section "Step 7: Running Django Migrations"

# Update DATABASE_URL in django-issuer-platform/.env to use Docker container
if [ -f "./django-issuer-platform/.env" ]; then
    log_step "Updating DATABASE_URL for Docker..."
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}|" django-issuer-platform/.env
    sed -i "s|REDIS_URL=.*|REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:${REDIS_PORT}/0|" django-issuer-platform/.env
    log_info "Updated connection strings"
fi

if [ -d "./django-issuer-platform" ]; then
    log_step "Running Django migrations..."
    cd django-issuer-platform
    
    # Create venv if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    pip install -q -r requirements.txt
    
    export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
    python manage.py migrate
    
    deactivate
    cd ..
    log_info "Django migrations completed"
else
    log_warn "django-issuer-platform directory not found"
fi

#######################
# STEP 8: Verification
#######################
log_section "Step 8: Running Verification"

if [ -f "./verify-dual-ledger-vps.sh" ]; then
    ./verify-dual-ledger-vps.sh
else
    log_warn "verify-dual-ledger-vps.sh not found"
fi

#######################
# FINAL OUTPUT
#######################
log_section "✅ Docker Infrastructure Setup Complete!"

echo ""
echo "📋 Service Access:"
echo "─────────────────────────────────────────"
echo "PostgreSQL:     localhost:${POSTGRES_PORT}"
echo "Redis:          localhost:${REDIS_PORT}"
echo "Keycloak:       http://localhost:${KEYCLOAK_PORT}"
echo ""
echo "🔑 Credentials (saved in .env.docker):"
echo "─────────────────────────────────────────"
echo "PostgreSQL User:     ${POSTGRES_USER}"
echo "Keycloak Admin:      ${KEYCLOAK_ADMIN}"
echo "Keycloak Admin URL:  http://localhost:${KEYCLOAK_PORT}/admin"
echo ""
echo "🚀 Next Steps:"
echo "─────────────────────────────────────────"
echo "1. Access Keycloak admin console:"
echo "   http://localhost:${KEYCLOAK_PORT}/admin"
echo "   Username: ${KEYCLOAK_ADMIN}"
echo "   Password: (check .env.docker)"
echo ""
echo "2. Start Django application:"
echo "   cd django-issuer-platform"
echo "   source venv/bin/activate"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "3. Or start full Docker stack:"
echo "   ./setup-env-docker.sh --full"
echo ""
echo "📊 Manage Services:"
echo "─────────────────────────────────────────"
echo "View logs:     docker-compose -f docker-compose.vps.yml logs -f"
echo "Stop services: docker-compose -f docker-compose.vps.yml down"
echo "Restart:       docker-compose -f docker-compose.vps.yml restart"
echo ""
log_info "Setup completed successfully! 🎉"
