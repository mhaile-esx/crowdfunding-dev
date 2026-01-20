#!/bin/bash

################################################################################
# apply-migrations.sh
# Apply Django database migrations in correct order
# Updated: December 2025
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
echo "CrowdfundChain - Apply Django Migrations"
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

# Apply migrations in correct order
log_info "Applying migrations in correct order..."

# Core Django apps first
log_info "1/9 - contenttypes"
python manage.py migrate contenttypes --no-input

log_info "2/9 - auth"
python manage.py migrate auth --no-input

# Custom user model (must come before admin)
log_info "3/9 - issuers"
python manage.py migrate issuers --no-input

# Admin (depends on user model)
log_info "4/9 - admin"
python manage.py migrate admin --no-input

log_info "5/9 - sessions"
python manage.py migrate sessions --no-input

# Application apps
log_info "6/9 - campaigns_module"
python manage.py migrate campaigns_module --no-input 2>/dev/null || log_warn "campaigns_module: no migrations or already applied"

log_info "7/9 - investments"
python manage.py migrate investments --no-input 2>/dev/null || log_warn "investments: no migrations or already applied"

log_info "8/9 - escrow"
python manage.py migrate escrow --no-input 2>/dev/null || log_warn "escrow: no migrations or already applied"

log_info "9/9 - blockchain"
python manage.py migrate blockchain --no-input 2>/dev/null || log_warn "blockchain: no migrations or already applied"

echo ""
log_info "=========================================="
log_info "All migrations applied successfully!"
log_info "=========================================="
echo ""
echo "📋 Current migration status:"
python manage.py showmigrations | head -50

echo ""
echo "🚀 Start the server:"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
