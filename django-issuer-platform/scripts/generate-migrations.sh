#!/bin/bash

################################################################################
# generate-migrations.sh
# Generate Django database migrations for all apps
# Updated: December 2025 - Removed duplicate apps (campaigns, nft)
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
echo "CrowdfundChain - Generate Django Migrations"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "Please run this script from the django-issuer-platform directory"
    exit 1
fi

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
    log_info "Virtual environment activated"
fi

# Create migrations directories if they don't exist
APPS=("issuers" "campaigns_module" "investments" "escrow" "blockchain")

log_info "Creating migrations directories..."
for app in "${APPS[@]}"; do
    if [ ! -d "${app}/migrations" ]; then
        mkdir -p "${app}/migrations"
        touch "${app}/migrations/__init__.py"
        log_info "Created: ${app}/migrations/"
    fi
done

# Generate migrations for active apps only
# Note: 'campaigns' removed (use campaigns_module), 'nft' removed (use investments.NFTShareCertificate)
log_info "Generating migrations..."
for app in "${APPS[@]}"; do
    log_info "  - ${app}"
    python manage.py makemigrations ${app} --no-input 2>/dev/null || log_warn "No changes in ${app}"
done

# Show migration plan
echo ""
log_info "=========================================="
log_info "Migrations generated successfully!"
log_info "=========================================="
echo ""
echo "📋 Migration plan:"
python manage.py showmigrations

echo ""
echo "🚀 To apply migrations, run:"
echo "   python manage.py migrate"
echo ""
echo "📌 Migration order (if manual):"
echo "   1. python manage.py migrate contenttypes"
echo "   2. python manage.py migrate auth"
echo "   3. python manage.py migrate issuers"
echo "   4. python manage.py migrate admin"
echo "   5. python manage.py migrate sessions"
echo "   6. python manage.py migrate campaigns_module"
echo "   7. python manage.py migrate investments"
echo "   8. python manage.py migrate escrow"
echo "   9. python manage.py migrate blockchain"
echo ""
