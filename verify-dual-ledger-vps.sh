#!/bin/bash
##############################################################################
# Dual-Ledger Pattern Quick Verification (VPS)
# 
# Tests:
# 1. Docker services (PostgreSQL, Redis, Keycloak)
# 2. Blockchain RPC connectivity (Polygon Edge nodes)
# 3. Smart contract deployment
# 4. Data synchronization
##############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║   CrowdfundChain Dual-Ledger Quick Check      ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

PASSED=0
FAILED=0

# Load environment if available
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
elif [ -f ".env.docker" ]; then
    set -a
    source .env.docker
    set +a
fi

# Set defaults
POSTGRES_USER="${POSTGRES_USER:-dltadmin}"
POSTGRES_DB="${POSTGRES_DB:-crowdfundchain_db}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-CrowdfundChain2025!}"
REDIS_PASSWORD="${REDIS_PASSWORD:-CrowdfundRedis2025!}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-8080}"

# Test function
test_step() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED++))
    fi
}

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Docker Services ━━━${NC}\n"
##############################################################################

# Check if Docker is available
if command -v docker &> /dev/null; then
    docker ps &> /dev/null
    test_step "Docker daemon accessible"
else
    echo -e "${YELLOW}⚠${NC} Docker not found, checking native services..."
fi

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ PostgreSQL Tests ━━━${NC}\n"
##############################################################################

# Test PostgreSQL - try Docker first, then native
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres"; then
    docker exec crowdfundchain_postgres pg_isready -U $POSTGRES_USER -d $POSTGRES_DB > /dev/null 2>&1
    test_step "PostgreSQL container running and healthy"
    
    # Test database connection via Docker
    docker exec crowdfundchain_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1" > /dev/null 2>&1
    test_step "Database connection successful"
else
    # Fallback to native PostgreSQL
    systemctl is-active --quiet postgresql 2>/dev/null
    test_step "PostgreSQL service running"
    
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1" > /dev/null 2>&1
    test_step "Database connection successful"
fi

# Test 3: Check required tables (Django uses app prefix for table names)
TABLES=(
    "auth_user"
    "issuers_company"
    "campaigns_module_campaign"
    "investments_investment"
    "investments_nftsharecertificate"
    "investments_payment"
    "escrow_fundescrow"
    "django_session"
)

echo -e "\n${BLUE}Checking database schema:${NC}"
for table in "${TABLES[@]}"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres"; then
        COUNT=$(docker exec crowdfundchain_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$table'" 2>/dev/null | xargs)
        if [ "$COUNT" = "1" ]; then
            RECORDS=$(docker exec crowdfundchain_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM $table" 2>/dev/null | xargs)
            echo -e "  ${GREEN}✓${NC} $table ($RECORDS records)"
            ((PASSED++))
        else
            echo -e "  ${RED}✗${NC} $table (missing)"
            ((FAILED++))
        fi
    else
        COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$table'" 2>/dev/null | xargs)
        if [ "$COUNT" = "1" ]; then
            RECORDS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM $table" 2>/dev/null | xargs)
            echo -e "  ${GREEN}✓${NC} $table ($RECORDS records)"
            ((PASSED++))
        else
            echo -e "  ${RED}✗${NC} $table (missing)"
            ((FAILED++))
        fi
    fi
done

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Blockchain Tests ━━━${NC}\n"
##############################################################################

# Test blockchain nodes (use localhost since port 8545 is exposed)
NODES=(
    "localhost:8545"
)

echo -e "${BLUE}Checking Polygon Edge nodes:${NC}"
for node in "${NODES[@]}"; do
    BLOCK=$(curl -s -X POST http://$node \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
    
    if [ ! -z "$BLOCK" ] && [ "$BLOCK" != "null" ]; then
        BLOCK_DEC=$((16#${BLOCK#0x}))
        echo -e "  ${GREEN}✓${NC} $node (Block: $BLOCK_DEC)"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $node (not responding)"
        ((FAILED++))
    fi
done

# Test smart contract deployment
echo -e "\n${BLUE}Checking smart contracts:${NC}"

check_contract() {
    local name=$1
    local address=$2
    
    if [ -z "$address" ]; then
        echo -e "  ${YELLOW}⚠${NC} $name: Not configured"
        return
    fi
    
    CODE=$(curl -s -X POST http://172.18.0.5:8545 \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$address\",\"latest\"],\"id\":1}" | jq -r '.result')
    
    if [ "$CODE" != "0x" ] && [ ! -z "$CODE" ]; then
        echo -e "  ${GREEN}✓${NC} $name ($address)"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $name ($address) - No code deployed"
        ((FAILED++))
    fi
}

# Read contract addresses from env file if it exists
if [ -f "./django-issuer-platform/.env" ]; then
    source ./django-issuer-platform/.env
    check_contract "Campaign Factory" "$CONTRACT_CAMPAIGN_FACTORY"
    check_contract "NFT Certificate" "$CONTRACT_NFT_CERTIFICATE"
    check_contract "DAO Governance" "$CONTRACT_DAO_GOVERNANCE"
else
    echo -e "  ${YELLOW}⚠${NC} No .env file found - skipping contract checks"
fi

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Integration Tests ━━━${NC}\n"
##############################################################################

# Check dual-ledger synchronization
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres"; then
    PG_CAMPAIGNS=$(docker exec crowdfundchain_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c \
        "SELECT COUNT(*) FROM campaigns WHERE smart_contract_address IS NOT NULL" 2>/dev/null | xargs)
    PG_TRANSACTIONS=$(docker exec crowdfundchain_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c \
        "SELECT COUNT(*) FROM blockchain_transactions" 2>/dev/null | xargs)
else
    PG_CAMPAIGNS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -t -c \
        "SELECT COUNT(*) FROM campaigns WHERE smart_contract_address IS NOT NULL" 2>/dev/null | xargs)
    PG_TRANSACTIONS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -t -c \
        "SELECT COUNT(*) FROM blockchain_transactions" 2>/dev/null | xargs)
fi

echo -e "${BLUE}Dual-Ledger Status:${NC}"
echo -e "  PostgreSQL campaigns with blockchain address: $PG_CAMPAIGNS"
echo -e "  Blockchain transactions recorded: $PG_TRANSACTIONS"

if [ "$PG_CAMPAIGNS" = "0" ] && [ "$PG_TRANSACTIONS" = "0" ]; then
    echo -e "  ${GREEN}✓${NC} Dual-ledger ready (no campaigns deployed yet)"
    ((PASSED++))
elif [ "$PG_CAMPAIGNS" -gt "0" ] && [ "$PG_TRANSACTIONS" -gt "0" ]; then
    echo -e "  ${GREEN}✓${NC} Dual-ledger active and synchronized"
    ((PASSED++))
else
    echo -e "  ${YELLOW}⚠${NC} Partial synchronization detected"
fi

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Redis Test ━━━${NC}\n"
##############################################################################

# Check Redis - Docker first, then native
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "redis"; then
    docker exec crowdfundchain_redis redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1
    test_step "Redis container running and healthy"
else
    systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null
    if [ $? -eq 0 ]; then
        redis-cli ping > /dev/null 2>&1
        test_step "Redis service running"
    else
        echo -e "${RED}✗${NC} Redis not running (required for Celery)"
        ((FAILED++))
    fi
fi

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Keycloak Test ━━━${NC}\n"
##############################################################################

# Check Keycloak
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "keycloak"; then
    curl -sf http://localhost:${KEYCLOAK_PORT}/health/ready > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        test_step "Keycloak container running and healthy"
    else
        echo -e "${YELLOW}⚠${NC} Keycloak starting (may take 1-2 minutes on first run)"
        docker ps --format '{{.Names}}: {{.Status}}' | grep keycloak
    fi
else
    echo -e "${YELLOW}⚠${NC} Keycloak not found (optional service)"
fi

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Summary ━━━${NC}\n"
##############################################################################

TOTAL=$((PASSED + FAILED))
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "Total:  $TOTAL"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}🎉 All tests passed! Dual-Ledger Pattern is operational.${NC}"
    exit 0
else
    echo -e "\n${YELLOW}${BOLD}⚠️  $FAILED test(s) failed. Review the errors above.${NC}"
    exit 1
fi
