#!/bin/bash
##############################################################################
# Dual-Ledger Pattern Quick Verification (VPS)
# 
# Tests:
# 1. PostgreSQL connection and tables
# 2. Blockchain RPC connectivity
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
echo -e "\n${BOLD}${BLUE}━━━ PostgreSQL Tests ━━━${NC}\n"
##############################################################################

# Test 1: PostgreSQL is running
systemctl is-active --quiet postgresql
test_step "PostgreSQL service running"

# Test 2: Database connection
psql -h localhost -U dltadmin -d crowdfundchain_db -c "SELECT 1" > /dev/null 2>&1
test_step "Database connection successful"

# Test 3: Check required tables
TABLES=(
    "users"
    "companies"
    "campaigns"
    "investments"
    "blockchain_transactions"
    "smart_contracts"
    "blockchain_sync"
    "wallets"
    "nft_shares"
)

echo -e "\n${BLUE}Checking database schema:${NC}"
for table in "${TABLES[@]}"; do
    COUNT=$(psql -h localhost -U dltadmin -d crowdfundchain_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$table'" 2>/dev/null | xargs)
    if [ "$COUNT" = "1" ]; then
        RECORDS=$(psql -h localhost -U dltadmin -d crowdfundchain_db -t -c "SELECT COUNT(*) FROM $table" 2>/dev/null | xargs)
        echo -e "  ${GREEN}✓${NC} $table ($RECORDS records)"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $table (missing)"
        ((FAILED++))
    fi
done

##############################################################################
echo -e "\n${BOLD}${BLUE}━━━ Blockchain Tests ━━━${NC}\n"
##############################################################################

# Test blockchain nodes
NODES=(
    "172.18.0.5:8545"
    "172.18.0.3:8545"
    "172.18.0.2:8545"
    "172.18.0.4:8545"
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
PG_CAMPAIGNS=$(psql -h localhost -U dltadmin -d crowdfundchain_db -t -c \
    "SELECT COUNT(*) FROM campaigns WHERE smart_contract_address IS NOT NULL" 2>/dev/null | xargs)

PG_TRANSACTIONS=$(psql -h localhost -U dltadmin -d crowdfundchain_db -t -c \
    "SELECT COUNT(*) FROM blockchain_transactions" 2>/dev/null | xargs)

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

systemctl is-active --quiet redis-server || systemctl is-active --quiet redis
if [ $? -eq 0 ]; then
    redis-cli ping > /dev/null 2>&1
    test_step "Redis service running"
else
    echo -e "${RED}✗${NC} Redis not running (required for Celery)"
    ((FAILED++))
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
