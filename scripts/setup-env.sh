#!/bin/bash

################################################################################
# CrowdfundChain - Complete Environment Setup Script
# 
# This script:
# 1. Deploys smart contracts to blockchain
# 2. Extracts contract addresses from deployment files
# 3. Gathers blockchain network information
# 4. Generates/retrieves platform wallet keys
# 5. Creates complete .env file for Django platform
################################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
CYAN='\033[0;96m'
NC='\033[0m'

# Configuration
DJANGO_DIR="./django-issuer-platform"
CONTRACTS_DIR="./smart-contracts"
DEPLOYMENT_FILE=""
ENV_FILE="$DJANGO_DIR/.env"
NETWORK="localhost"  # Default to localhost, can be overridden

# Functions
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
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --network NETWORK    Blockchain network (localhost, mumbai, polygon)"
            echo "  --rpc-url URL        Custom RPC URL (default: http://localhost:8545)"
            echo "  --skip-deploy        Skip contract deployment, use existing deployment"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Deploy to localhost"
            echo "  $0 --network localhost --rpc-url http://45.76.159.34:8545"
            echo "  $0 --skip-deploy                     # Use existing deployment"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set default RPC URL if not provided
if [ -z "$RPC_URL" ]; then
    if [ "$NETWORK" = "localhost" ]; then
        RPC_URL="http://localhost:8545"
    elif [ "$NETWORK" = "mumbai" ]; then
        RPC_URL="https://rpc-mumbai.maticvigil.com"
    elif [ "$NETWORK" = "polygon" ]; then
        RPC_URL="https://polygon-rpc.com"
    else
        RPC_URL="http://localhost:8545"
    fi
fi

log_section "CrowdfundChain Environment Setup"

echo "Configuration:"
echo "  Network: $NETWORK"
echo "  RPC URL: $RPC_URL"
echo "  Django Dir: $DJANGO_DIR"
echo "  Environment File: $ENV_FILE"
echo ""

#######################
# STEP 1: CHECK PREREQUISITES
#######################
log_section "Step 1: Checking Prerequisites"

# Check if Django directory exists
if [ ! -d "$DJANGO_DIR" ]; then
    log_error "Django directory not found: $DJANGO_DIR"
    exit 1
fi
log_info "Django directory found"

# Check if smart-contracts directory exists
if [ ! -d "$CONTRACTS_DIR" ]; then
    log_error "Smart contracts directory not found: $CONTRACTS_DIR"
    exit 1
fi
log_info "Smart contracts directory found"

# Check if node/npm is installed
if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed"
    exit 1
fi
log_info "Node.js found: $(node --version)"

# Check if npx is available
if ! command -v npx &> /dev/null; then
    log_error "npx is not installed"
    exit 1
fi
log_info "npx found"

# Check blockchain connection
log_step "Testing blockchain connection at $RPC_URL..."
BLOCK_NUMBER=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "$RPC_URL" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BLOCK_NUMBER" ]; then
    log_error "Cannot connect to blockchain at $RPC_URL"
    log_error "Please start the blockchain network first"
    exit 1
fi

# Convert hex to decimal
BLOCK_NUMBER_DEC=$((16#${BLOCK_NUMBER#0x}))
log_info "Blockchain connected (Current block: $BLOCK_NUMBER_DEC)"

# Get chain ID
CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    "$RPC_URL" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
CHAIN_ID_DEC=$((16#${CHAIN_ID#0x}))
log_info "Chain ID: $CHAIN_ID_DEC"

#######################
# STEP 2: DEPLOY SMART CONTRACTS
#######################
if [ "$SKIP_DEPLOY" = true ]; then
    log_section "Step 2: Skipping Contract Deployment"
    log_warn "Using existing deployment files"
else
    log_section "Step 2: Deploying Smart Contracts"
    
    log_step "Installing dependencies..."
    cd "$CONTRACTS_DIR"
    npm install --silent 2>&1 | grep -v "npm WARN" || true
    cd ..
    log_info "Dependencies installed"
    
    log_step "Deploying contracts to $NETWORK..."
    echo ""
    
    # Deploy contracts
    cd "$CONTRACTS_DIR"
    npx hardhat run deploy.js --network "$NETWORK"
    DEPLOY_EXIT_CODE=$?
    cd ..
    
    if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
        log_error "Contract deployment failed"
        exit 1
    fi
    
    echo ""
    log_info "Contracts deployed successfully"
fi

#######################
# STEP 3: EXTRACT CONTRACT ADDRESSES
#######################
log_section "Step 3: Extracting Contract Addresses"

# Find deployment file
DEPLOYMENT_FILE="$CONTRACTS_DIR/deployments/${NETWORK}.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    log_error "Deployment file not found: $DEPLOYMENT_FILE"
    log_error "Available deployments:"
    ls -la "$CONTRACTS_DIR/deployments/" 2>/dev/null || echo "  No deployments found"
    exit 1
fi

log_info "Found deployment file: $DEPLOYMENT_FILE"

# Extract contract addresses using jq or python
if command -v jq &> /dev/null; then
    # Use jq if available
    NFT_CONTRACT=$(jq -r '.contracts.nftShareCertificate.address' "$DEPLOYMENT_FILE")
    DAO_CONTRACT=$(jq -r '.contracts.daoGovernance.address' "$DEPLOYMENT_FILE")
    FACTORY_CONTRACT=$(jq -r '.contracts.campaignFactory.address' "$DEPLOYMENT_FILE")
    IMPLEMENTATION_CONTRACT=$(jq -r '.contracts.campaignImplementation.address' "$DEPLOYMENT_FILE")
    DEPLOYER_ADDRESS=$(jq -r '.deployer' "$DEPLOYMENT_FILE")
else
    # Fallback to python
    NFT_CONTRACT=$(python3 -c "import json; print(json.load(open('$DEPLOYMENT_FILE'))['contracts']['nftShareCertificate']['address'])")
    DAO_CONTRACT=$(python3 -c "import json; print(json.load(open('$DEPLOYMENT_FILE'))['contracts']['daoGovernance']['address'])")
    FACTORY_CONTRACT=$(python3 -c "import json; print(json.load(open('$DEPLOYMENT_FILE'))['contracts']['campaignFactory']['address'])")
    IMPLEMENTATION_CONTRACT=$(python3 -c "import json; print(json.load(open('$DEPLOYMENT_FILE'))['contracts']['campaignImplementation']['address'])")
    DEPLOYER_ADDRESS=$(python3 -c "import json; print(json.load(open('$DEPLOYMENT_FILE'))['deployer'])")
fi

log_info "NFT Certificate: $NFT_CONTRACT"
log_info "DAO Governance: $DAO_CONTRACT"
log_info "Campaign Factory: $FACTORY_CONTRACT"
log_info "Campaign Implementation: $IMPLEMENTATION_CONTRACT"
log_info "Deployer Address: $DEPLOYER_ADDRESS"

#######################
# STEP 4: GENERATE PLATFORM WALLET
#######################
log_section "Step 4: Platform Wallet Configuration"

# Check if we should reuse deployer wallet or generate new one
log_step "Checking for existing platform wallet..."

# Look for existing private key in .env.example or hardhat config
PLATFORM_PRIVATE_KEY=""

# Check .env.example
if [ -f "$DJANGO_DIR/.env.example" ]; then
    EXISTING_KEY=$(grep "BLOCKCHAIN_DEPLOYER_PRIVATE_KEY" "$DJANGO_DIR/.env.example" | cut -d'=' -f2)
    if [ ! -z "$EXISTING_KEY" ] && [ "$EXISTING_KEY" != "" ]; then
        PLATFORM_PRIVATE_KEY="$EXISTING_KEY"
        log_info "Using private key from .env.example"
    fi
fi

# If still no key, use hardhat's default account
if [ -z "$PLATFORM_PRIVATE_KEY" ]; then
    # Hardhat's default first account private key
    PLATFORM_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    log_warn "Using Hardhat's default account private key (CHANGE IN PRODUCTION!)"
fi

# Calculate address from private key using node
PLATFORM_ADDRESS=$(node -e "
const { ethers } = require('ethers');
const wallet = new ethers.Wallet('$PLATFORM_PRIVATE_KEY');
console.log(wallet.address);
" 2>/dev/null)

if [ -z "$PLATFORM_ADDRESS" ]; then
    PLATFORM_ADDRESS="$DEPLOYER_ADDRESS"
    log_warn "Could not calculate address, using deployer address"
fi

log_info "Platform Wallet: $PLATFORM_ADDRESS"

#######################
# STEP 5: GATHER ADDITIONAL INFO
#######################
log_section "Step 5: Gathering Additional Information"

# Generate Django secret key
log_step "Generating Django secret key..."
DJANGO_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
log_info "Secret key generated"

# Get current timestamp
GENERATION_TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Detect server IP (for ALLOWED_HOSTS)
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
log_info "Server IP: $SERVER_IP"

#######################
# STEP 6: CREATE .ENV FILE
#######################
log_section "Step 6: Creating Environment File"

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
    BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    log_warn "Existing .env backed up to: $BACKUP_FILE"
fi

# Create new .env file
log_step "Writing configuration to $ENV_FILE..."

cat > "$ENV_FILE" <<EOF
################################################################################
# CrowdfundChain Django Platform - Environment Configuration
# 
# Auto-generated on: $GENERATION_TIMESTAMP
# Network: $NETWORK
# Chain ID: $CHAIN_ID_DEC
# Current Block: $BLOCK_NUMBER_DEC
################################################################################

#######################
# DJANGO SETTINGS
#######################
SECRET_KEY=$DJANGO_SECRET_KEY
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,$SERVER_IP

#######################
# DATABASE
#######################
DATABASE_URL=postgresql://dltadmin:CrowdfundChain2025!@localhost:5432/crowdfundchain_db
POSTGRES_DB=crowdfundchain_db
POSTGRES_USER=dltadmin
POSTGRES_PASSWORD=CrowdfundChain2025!
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

#######################
# REDIS (Celery Broker)
#######################
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

#######################
# BLOCKCHAIN CONFIGURATION
#######################
# Network Information
POLYGON_EDGE_RPC_URL=$RPC_URL
BLOCKCHAIN_RPC_URL=$RPC_URL
CHAIN_ID=$CHAIN_ID_DEC
NETWORK_NAME=$NETWORK

# Platform Wallet (for executing blockchain transactions)
BLOCKCHAIN_DEPLOYER_PRIVATE_KEY=$PLATFORM_PRIVATE_KEY
BLOCKCHAIN_DEPLOYER_ADDRESS=$PLATFORM_ADDRESS
BLOCKCHAIN_PLATFORM_ADDRESS=$PLATFORM_ADDRESS

#######################
# SMART CONTRACT ADDRESSES
#######################
# Deployed on: $GENERATION_TIMESTAMP
# Network: $NETWORK (Chain ID: $CHAIN_ID_DEC)

# Core Contracts
CONTRACT_NFT_CERTIFICATE=$NFT_CONTRACT
CONTRACT_DAO_GOVERNANCE=$DAO_CONTRACT
CONTRACT_CAMPAIGN_FACTORY=$FACTORY_CONTRACT
CONTRACT_CAMPAIGN_IMPLEMENTATION=$IMPLEMENTATION_CONTRACT

# Legacy naming (for backward compatibility)
CONTRACT_ISSUER_REGISTRY=$FACTORY_CONTRACT
CONTRACT_FUND_ESCROW=$FACTORY_CONTRACT

# Contract ABIs Path
CONTRACT_ABIS_PATH=blockchain/contract_abis/

#######################
# IPFS CONFIGURATION
#######################
# For document storage (optional, configure when ready)
IPFS_API_URL=https://ipfs.infura.io:5001
IPFS_GATEWAY_URL=https://ipfs.io/ipfs/
IPFS_PROJECT_ID=
IPFS_PROJECT_SECRET=

#######################
# EMAIL CONFIGURATION
#######################
# For notifications (configure for production)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@crowdfundchain.com

#######################
# PLATFORM SETTINGS
#######################
# Business logic parameters
PLATFORM_FEE_PERCENTAGE=2.5
SUCCESS_THRESHOLD_PERCENTAGE=75
MAX_CAMPAIGN_DURATION_DAYS=180
MIN_INVESTMENT_AMOUNT=100

# Compliance settings
KYC_VERIFICATION_REQUIRED=True
AML_SCREENING_ENABLED=True
MAX_DAILY_INVESTMENT_LIMIT=1000000

#######################
# KEYCLOAK INTEGRATION (Optional)
#######################
# For enterprise SSO (configure if needed)
KEYCLOAK_URL=
KEYCLOAK_REALM=crowdfundchain
KEYCLOAK_CLIENT_ID=issuer-platform
KEYCLOAK_CLIENT_SECRET=

#######################
# MONITORING & LOGGING
#######################
# Sentry error tracking (configure for production)
SENTRY_DSN=
SENTRY_ENVIRONMENT=$NETWORK

# Log levels
LOG_LEVEL=INFO
DJANGO_LOG_LEVEL=INFO
CELERY_LOG_LEVEL=INFO

#######################
# CORS SETTINGS
#######################
# Allowed origins for API access
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000,http://$SERVER_IP:8000

#######################
# SECURITY SETTINGS
#######################
# Session and CSRF
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
SECURE_SSL_REDIRECT=False

# Set to True in production with HTTPS
# SESSION_COOKIE_SECURE=True
# CSRF_COOKIE_SECURE=True
# SECURE_SSL_REDIRECT=True

#######################
# DEPLOYMENT INFO
#######################
# Metadata for reference
DEPLOYMENT_DATE=$GENERATION_TIMESTAMP
DEPLOYMENT_NETWORK=$NETWORK
DEPLOYMENT_CHAIN_ID=$CHAIN_ID_DEC
DEPLOYMENT_BLOCK=$BLOCK_NUMBER_DEC
DEPLOYMENT_FILE=$DEPLOYMENT_FILE

################################################################################
# END OF AUTO-GENERATED CONFIGURATION
# 
# SECURITY NOTES:
# 1. CHANGE DEFAULT PASSWORDS IN PRODUCTION
# 2. NEVER COMMIT THIS FILE TO VERSION CONTROL
# 3. USE ENVIRONMENT-SPECIFIC VALUES FOR PRODUCTION
# 4. ROTATE PRIVATE KEYS REGULARLY
# 5. ENABLE SSL/TLS IN PRODUCTION
################################################################################
EOF

log_info "Environment file created successfully"

#######################
# STEP 7: CREATE CONTRACT ABI FILES
#######################
log_section "Step 7: Copying Contract ABIs"

ABI_DIR="$DJANGO_DIR/blockchain/contract_abis"
mkdir -p "$ABI_DIR"

log_step "Extracting and copying contract ABIs..."

# Copy ABI files from smart-contracts/artifacts
if [ -d "$CONTRACTS_DIR/artifacts/contracts" ]; then
    # Find and copy NFT contract ABI
    find "$CONTRACTS_DIR/artifacts/contracts" -name "NFTShareCertificate.json" -exec cp {} "$ABI_DIR/" \; 2>/dev/null || true
    
    # Find and copy DAO contract ABI
    find "$CONTRACTS_DIR/artifacts/contracts" -name "DAOGovernance.json" -exec cp {} "$ABI_DIR/" \; 2>/dev/null || true
    
    # Find and copy Factory contract ABI
    find "$CONTRACTS_DIR/artifacts/contracts" -name "CampaignFactory.json" -exec cp {} "$ABI_DIR/" \; 2>/dev/null || true
    
    # Find and copy Implementation contract ABI
    find "$CONTRACTS_DIR/artifacts/contracts" -name "CampaignImplementation.json" -exec cp {} "$ABI_DIR/" \; 2>/dev/null || true
    
    log_info "Contract ABIs copied to $ABI_DIR"
else
    log_warn "Contract artifacts directory not found, skipping ABI copy"
    log_warn "Run 'cd $CONTRACTS_DIR && npx hardhat compile' to generate ABIs"
fi

#######################
# STEP 8: CREATE ENV SUMMARY
#######################
log_section "Step 8: Configuration Summary"

# Create a summary file
SUMMARY_FILE="$DJANGO_DIR/deployment-summary.txt"

cat > "$SUMMARY_FILE" <<EOF
CrowdfundChain Platform - Deployment Summary
Generated: $GENERATION_TIMESTAMP

NETWORK INFORMATION
==================
Network: $NETWORK
Chain ID: $CHAIN_ID_DEC
RPC URL: $RPC_URL
Current Block: $BLOCK_NUMBER_DEC

SMART CONTRACT ADDRESSES
=======================
NFT Certificate:         $NFT_CONTRACT
DAO Governance:          $DAO_CONTRACT
Campaign Factory:        $FACTORY_CONTRACT
Campaign Implementation: $IMPLEMENTATION_CONTRACT

PLATFORM WALLET
==============
Address: $PLATFORM_ADDRESS
Private Key: ${PLATFORM_PRIVATE_KEY:0:20}...${PLATFORM_PRIVATE_KEY: -10} (truncated for security)

DATABASE
========
Host: localhost:5432
Database: crowdfundchain_db
User: dltadmin

FILES CREATED
=============
1. $ENV_FILE
2. $ABI_DIR/*.json
3. $SUMMARY_FILE

NEXT STEPS
==========
1. Review the .env file: nano $ENV_FILE
2. Update database password if needed
3. Run Django migrations: python manage.py migrate
4. Create superuser: python manage.py createsuperuser
5. Start services:
   - Django: gunicorn issuer_platform.wsgi:application
   - Celery: celery -A issuer_platform worker -l info
6. Test blockchain connection: python manage.py shell

SECURITY CHECKLIST
==================
[ ] Change database password in .env
[ ] Generate new platform wallet for production
[ ] Configure IPFS credentials
[ ] Set up email service (SendGrid, AWS SES, etc.)
[ ] Enable SSL/TLS in production
[ ] Configure Sentry for error tracking
[ ] Set DEBUG=False in production
[ ] Add production domain to ALLOWED_HOSTS

EOF

log_info "Summary saved to: $SUMMARY_FILE"

#######################
# FINAL OUTPUT
#######################
log_section "✅ Environment Setup Complete!"

echo ""
echo "📋 Configuration Summary:"
echo "─────────────────────────────────────────"
echo "Network:              $NETWORK"
echo "Chain ID:             $CHAIN_ID_DEC"
echo "RPC URL:              $RPC_URL"
echo "Platform Wallet:      $PLATFORM_ADDRESS"
echo ""
echo "📜 Smart Contracts:"
echo "─────────────────────────────────────────"
echo "NFT Certificate:      $NFT_CONTRACT"
echo "DAO Governance:       $DAO_CONTRACT"
echo "Campaign Factory:     $FACTORY_CONTRACT"
echo ""
echo "📁 Files Created:"
echo "─────────────────────────────────────────"
echo "✓ $ENV_FILE"
echo "✓ $SUMMARY_FILE"
echo "✓ $ABI_DIR/*.json"
echo ""
echo "🚀 Next Steps:"
echo "─────────────────────────────────────────"
echo "1. Review configuration:"
echo "   cat $ENV_FILE"
echo ""
echo "2. Run Django migrations:"
echo "   cd $DJANGO_DIR"
echo "   python manage.py migrate"
echo ""
echo "3. Create admin user:"
echo "   python manage.py createsuperuser"
echo ""
echo "4. Start the platform:"
echo "   sudo systemctl start issuer-platform"
echo "   sudo systemctl start celery-worker"
echo ""
echo "5. Test connection:"
echo "   python manage.py shell"
echo "   >>> from blockchain.web3_client import get_blockchain_client"
echo "   >>> client = get_blockchain_client()"
echo "   >>> client.w3.is_connected()"
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "─────────────────────────────────────────"
echo "• Never commit .env to version control"
echo "• Change default passwords before production"
echo "• Rotate platform wallet keys regularly"
echo "• Enable SSL/TLS in production"
echo ""
log_info "Setup completed successfully! 🎉"
echo ""
