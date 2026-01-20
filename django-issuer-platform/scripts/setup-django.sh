#!/bin/bash

################################################################################
# setup-django.sh
# Complete Django Platform Setup Script
# Updated: December 2025
#
# This script handles:
#   - Environment configuration
#   - Database connection
#   - Migration generation and application
#   - Static files
#   - Superuser creation
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo ""
echo "=========================================="
echo "CrowdfundChain - Django Platform Setup"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "Please run this script from the django-issuer-platform directory"
    exit 1
fi

#######################
# CONFIGURATION
#######################

# Default values
DB_NAME="${DB_NAME:-crowdfundchain_db}"
DB_USER="${DB_USER:-dltadmin}"
DB_PASSWORD="${DB_PASSWORD:-CrowdfundChain2025}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5433}"

REDIS_PASSWORD="${REDIS_PASSWORD:-CrowdfundRedis2025}"
REDIS_PORT="${REDIS_PORT:-6379}"

BLOCKCHAIN_RPC="${BLOCKCHAIN_RPC:-http://172.18.0.5:8545}"
CHAIN_ID="${CHAIN_ID:-100}"

#######################
# VIRTUAL ENVIRONMENT
#######################
log_step "Setting up virtual environment..."

if [ ! -d "venv" ]; then
    python3 -m venv venv
    log_info "Created virtual environment"
fi

source venv/bin/activate
log_info "Virtual environment activated"

# Upgrade pip
pip install --upgrade pip -q

#######################
# DEPENDENCIES
#######################
log_step "Installing dependencies..."

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt -q
    log_info "Dependencies installed"
else
    log_warn "requirements.txt not found, skipping dependency installation"
fi

#######################
# ENVIRONMENT FILE
#######################
log_step "Creating environment configuration..."

if [ ! -f ".env" ] || [ "$FORCE_ENV" = "true" ]; then
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
    
    cat > .env << EOF
# Database Configuration
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}

# Django Settings
DEBUG=True
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=localhost,127.0.0.1

# Redis Configuration
REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:${REDIS_PORT}/0
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@localhost:${REDIS_PORT}/0

# Blockchain Configuration
BLOCKCHAIN_RPC_URL=${BLOCKCHAIN_RPC}
CHAIN_ID=${CHAIN_ID}
EOF

    chmod 600 .env
    log_info "Environment file created: .env"
else
    log_info "Environment file exists, skipping (set FORCE_ENV=true to override)"
fi

#######################
# FIX APP CONFLICTS
#######################
log_step "Fixing app conflicts..."

# Fix investments/models.py
if grep -q "from campaigns.models import Campaign" investments/models.py 2>/dev/null; then
    sed -i 's/from campaigns.models import Campaign/from campaigns_module.models import Campaign/' investments/models.py
    log_info "Fixed: investments/models.py"
fi

# Fix blockchain/tasks.py
if grep -q "from campaigns.models import Campaign" blockchain/tasks.py 2>/dev/null; then
    sed -i 's/from campaigns.models import Campaign/from campaigns_module.models import Campaign/g' blockchain/tasks.py
    log_info "Fixed: blockchain/tasks.py"
fi

# Fix investments/tasks.py
if grep -q "from nft.tasks import mint_nft_certificate" investments/tasks.py 2>/dev/null; then
    sed -i 's/from nft.tasks import mint_nft_certificate/from blockchain.tasks import mint_nft_certificate/' investments/tasks.py
    log_info "Fixed: investments/tasks.py"
fi

#######################
# CREATE DIRECTORIES
#######################
log_step "Creating required directories..."

mkdir -p static
mkdir -p staticfiles
mkdir -p media
mkdir -p logs

log_info "Directories created"

#######################
# MIGRATIONS
#######################
log_step "Setting up database migrations..."

# Create migrations directories
APPS=("issuers" "campaigns_module" "investments" "escrow" "blockchain")

for app in "${APPS[@]}"; do
    if [ ! -d "${app}/migrations" ]; then
        mkdir -p "${app}/migrations"
        touch "${app}/migrations/__init__.py"
        log_info "Created: ${app}/migrations/"
    fi
done

# Generate migrations
log_info "Generating migrations..."
for app in "${APPS[@]}"; do
    python manage.py makemigrations ${app} --no-input 2>/dev/null || true
done

#######################
# DATABASE CONNECTION TEST
#######################
log_step "Testing database connection..."

python << 'EOF'
import os
import sys
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'issuer_platform.settings')

try:
    import django
    django.setup()
    from django.db import connection
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    print("Database connection: OK")
except Exception as e:
    print(f"Database connection: FAILED - {e}")
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    log_error "Database connection failed. Please check your .env configuration."
    log_warn "Make sure PostgreSQL is running on ${DB_HOST}:${DB_PORT}"
    exit 1
fi

#######################
# APPLY MIGRATIONS
#######################
log_step "Applying database migrations..."

# Apply in correct order
python manage.py migrate contenttypes --no-input
python manage.py migrate auth --no-input
python manage.py migrate issuers --no-input
python manage.py migrate admin --no-input
python manage.py migrate sessions --no-input
python manage.py migrate campaigns_module --no-input 2>/dev/null || true
python manage.py migrate investments --no-input 2>/dev/null || true
python manage.py migrate escrow --no-input 2>/dev/null || true
python manage.py migrate blockchain --no-input 2>/dev/null || true

log_info "Migrations applied"

#######################
# STATIC FILES
#######################
log_step "Collecting static files..."

python manage.py collectstatic --no-input -v 0 2>/dev/null || log_warn "collectstatic skipped"

log_info "Static files collected"

#######################
# SUPERUSER
#######################
log_step "Creating superuser..."

python << 'EOF'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'issuer_platform.settings')

import django
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(
        username='admin',
        email='admin@crowdfundchain.com',
        password='admin123'
    )
    print("Superuser created: admin / admin123")
else:
    print("Superuser 'admin' already exists")
EOF

#######################
# SUMMARY
#######################
echo ""
log_info "=========================================="
log_info "Django Platform Setup Complete!"
log_info "=========================================="
echo ""
echo "📊 Configuration:"
echo "   Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
echo "   User: ${DB_USER}"
echo ""
echo "🔐 Credentials:"
echo "   Admin User: admin"
echo "   Admin Password: admin123"
echo ""
echo "🚀 Start the server:"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "📌 Management Commands:"
echo "   python manage.py createsuperuser  - Create new admin"
echo "   python manage.py shell            - Django shell"
echo "   python manage.py dbshell          - Database shell"
echo ""
echo "⚠️  Security Reminders:"
echo "   1. Change admin password in production"
echo "   2. Set DEBUG=False in production"
echo "   3. Update SECRET_KEY"
echo ""
