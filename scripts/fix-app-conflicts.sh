#!/bin/bash

################################################################################
# fix-app-conflicts.sh
# Fixes Django app conflicts after removing duplicate apps
# Run this on VPS to fix import errors
# Created: December 3, 2025
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "CrowdfundChain - Django App Conflict Fix"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "Please run this script from the django-issuer-platform directory"
    exit 1
fi

log_info "Fixing import conflicts..."

# Fix 1: investments/models.py - Change campaigns import to campaigns_module
if grep -q "from campaigns.models import Campaign" investments/models.py 2>/dev/null; then
    sed -i 's/from campaigns.models import Campaign/from campaigns_module.models import Campaign/' investments/models.py
    log_info "Fixed: investments/models.py"
else
    log_info "Already fixed: investments/models.py"
fi

# Fix 2: blockchain/tasks.py - Change campaigns imports to campaigns_module
if grep -q "from campaigns.models import Campaign" blockchain/tasks.py 2>/dev/null; then
    sed -i 's/from campaigns.models import Campaign/from campaigns_module.models import Campaign/g' blockchain/tasks.py
    log_info "Fixed: blockchain/tasks.py"
else
    log_info "Already fixed: blockchain/tasks.py"
fi

# Fix 3: investments/tasks.py - Change nft.tasks import to blockchain.tasks
if grep -q "from nft.tasks import mint_nft_certificate" investments/tasks.py 2>/dev/null; then
    sed -i 's/from nft.tasks import mint_nft_certificate/from blockchain.tasks import mint_nft_certificate/' investments/tasks.py
    log_info "Fixed: investments/tasks.py"
else
    log_info "Already fixed: investments/tasks.py"
fi

# Fix 4: Create required directories
log_info "Creating required directories..."
mkdir -p static staticfiles media logs
log_info "Directories created"

# Fix 5: Create migrations directories
log_info "Creating migrations directories..."
APPS=("issuers" "campaigns_module" "investments" "escrow" "blockchain")
for app in "${APPS[@]}"; do
    if [ ! -d "${app}/migrations" ]; then
        mkdir -p "${app}/migrations"
        touch "${app}/migrations/__init__.py"
        log_info "Created: ${app}/migrations/"
    fi
done

# Fix 6: Verify settings.py has correct INSTALLED_APPS
log_info "Verifying settings.py configuration..."
SETTINGS_OK=true

if grep -q "'campaigns.apps.CampaignsConfig'" issuer_platform/settings.py 2>/dev/null; then
    log_warn "settings.py still has old 'campaigns' app"
    SETTINGS_OK=false
fi

if grep -q "'nft.apps.NftConfig'" issuer_platform/settings.py 2>/dev/null; then
    log_warn "settings.py still has old 'nft' app"
    SETTINGS_OK=false
fi

if [ "$SETTINGS_OK" = true ]; then
    log_info "settings.py correctly configured"
fi

echo ""
log_info "=========================================="
log_info "App conflict fixes complete!"
log_info "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run setup: ./scripts/setup-django.sh"
echo "  OR manually:"
echo "  2. Activate venv: source venv/bin/activate"
echo "  3. Generate migrations: ./scripts/generate-migrations.sh"
echo "  4. Apply migrations: python manage.py migrate"
echo "  5. Start server: python manage.py runserver 0.0.0.0:8000"
echo ""
echo "Active Django Apps:"
echo "  - issuers: User/company management, KYC/AML"
echo "  - campaigns_module: Campaign CRUD, documents, updates"
echo "  - investments: Investment tracking, NFT certificates, payments"
echo "  - escrow: Smart contract escrow management"
echo "  - blockchain: Web3 client, Celery tasks"
echo ""
