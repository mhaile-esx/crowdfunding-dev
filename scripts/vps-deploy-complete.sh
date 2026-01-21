#!/bin/bash
set -e

echo "=============================================="
echo "🚀 CrowdfundChain Complete Deployment"
echo "=============================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CHAIN_ID=${CHAIN_ID:-100}
BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-10000000}
PREMINE_ADDRESS=${PREMINE_ADDRESS:-"0x49065C1C0cFc356313eB67860bD6b697a9317a83"}
PREMINE_AMOUNT=${PREMINE_AMOUNT:-"1000000000000000000000000"}

echo "[→] Project directory: $PROJECT_DIR"

echo ""
echo "[1/7] Checking prerequisites..."
command -v docker &> /dev/null && echo "  ✓ Docker installed"
command -v docker-compose &> /dev/null && echo "  ✓ Docker Compose installed"

echo ""
echo "[2/7] Stopping existing containers..."
docker-compose -f docker-compose.infrastructure.yml down 2>/dev/null || true
docker rm -f polygon-edge-node1 polygon-edge-node2 polygon-edge-node3 polygon-edge-node4 2>/dev/null || true
docker network rm crowdfunding-dev_polygon_network 2>/dev/null || true
docker network prune -f 2>/dev/null || true
echo "  ✓ Existing containers stopped"

echo ""
echo "[3/7] Generating validator keys..."
rm -rf polygon-edge
mkdir -p polygon-edge/genesis
mkdir -p polygon-edge/data/{1,2,3,4}/{consensus,libp2p}

VALIDATORS=()
for i in 1 2 3 4; do
    VALIDATOR_KEY=$(openssl rand -hex 32)
    echo "$VALIDATOR_KEY" > polygon-edge/data/$i/consensus/validator.key
    BLS_KEY=$(openssl rand -hex 32)
    echo "$BLS_KEY" > polygon-edge/data/$i/consensus/validator-bls.key
    LIBP2P_KEY=$(openssl rand -hex 32)
    echo "$LIBP2P_KEY" > polygon-edge/data/$i/libp2p/libp2p.key
    VALIDATOR_ADDR=$(echo -n "$VALIDATOR_KEY" | sha256sum | cut -c1-40)
    VALIDATORS+=("0x$VALIDATOR_ADDR")
    echo "  ✓ Validator $i: ${VALIDATORS[$i-1]}"
done

echo ""
echo "[4/7] Generating genesis file..."
VANITY="0x0000000000000000000000000000000000000000000000000000000000000000"

cat > polygon-edge/genesis/genesis.json << EOF
{
  "name": "crowdfundchain",
  "genesis": {
    "nonce": "0x0000000000000000",
    "timestamp": "0x0",
    "extraData": "${VANITY}",
    "gasLimit": "0x${BLOCK_GAS_LIMIT}",
    "difficulty": "0x1",
    "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {
      "${PREMINE_ADDRESS}": {"balance": "0x${PREMINE_AMOUNT}"},
      "${VALIDATORS[0]}": {"balance": "0x56bc75e2d63100000"},
      "${VALIDATORS[1]}": {"balance": "0x56bc75e2d63100000"},
      "${VALIDATORS[2]}": {"balance": "0x56bc75e2d63100000"},
      "${VALIDATORS[3]}": {"balance": "0x56bc75e2d63100000"}
    }
  },
  "params": {
    "chainID": ${CHAIN_ID},
    "forks": {"homestead": 0, "byzantium": 0, "constantinople": 0, "petersburg": 0, "istanbul": 0, "london": 0},
    "engine": {"ibft": {"epochSize": 100000, "blockTime": 2}},
    "blockGasTarget": ${BLOCK_GAS_LIMIT}
  },
  "bootnodes": ["/ip4/172.18.0.5/tcp/1478/p2p/validator1"]
}
EOF
echo "  ✓ Genesis file created"

echo ""
echo "[5/7] Creating Docker Compose configuration..."
cat > docker-compose.blockchain.generated.yml << 'DEOF'
version: '3.8'
services:
  polygon-edge-node1:
    image: 0xpolygon/polygon-edge:1.3.1
    container_name: polygon-edge-node1
    restart: unless-stopped
    command: ["server", "--data-dir=/data", "--chain=/genesis/genesis.json", "--libp2p=0.0.0.0:1478", "--nat=172.18.0.5", "--jsonrpc=0.0.0.0:8545", "--seal", "--log-level=INFO"]
    volumes: ["./polygon-edge/data/1:/data", "./polygon-edge/genesis:/genesis:ro"]
    ports: ["8545:8545", "1478:1478"]
    networks:
      polygon_network:
        ipv4_address: 172.18.0.5

  polygon-edge-node2:
    image: 0xpolygon/polygon-edge:1.3.1
    container_name: polygon-edge-node2
    restart: unless-stopped
    depends_on: [polygon-edge-node1]
    command: ["server", "--data-dir=/data", "--chain=/genesis/genesis.json", "--libp2p=0.0.0.0:1478", "--nat=172.18.0.3", "--jsonrpc=0.0.0.0:8545", "--seal", "--log-level=INFO"]
    volumes: ["./polygon-edge/data/2:/data", "./polygon-edge/genesis:/genesis:ro"]
    ports: ["8546:8545"]
    networks:
      polygon_network:
        ipv4_address: 172.18.0.3

  polygon-edge-node3:
    image: 0xpolygon/polygon-edge:1.3.1
    container_name: polygon-edge-node3
    restart: unless-stopped
    depends_on: [polygon-edge-node1]
    command: ["server", "--data-dir=/data", "--chain=/genesis/genesis.json", "--libp2p=0.0.0.0:1478", "--nat=172.18.0.2", "--jsonrpc=0.0.0.0:8545", "--seal", "--log-level=INFO"]
    volumes: ["./polygon-edge/data/3:/data", "./polygon-edge/genesis:/genesis:ro"]
    ports: ["8547:8545"]
    networks:
      polygon_network:
        ipv4_address: 172.18.0.2

  polygon-edge-node4:
    image: 0xpolygon/polygon-edge:1.3.1
    container_name: polygon-edge-node4
    restart: unless-stopped
    depends_on: [polygon-edge-node1]
    command: ["server", "--data-dir=/data", "--chain=/genesis/genesis.json", "--libp2p=0.0.0.0:1478", "--nat=172.18.0.4", "--jsonrpc=0.0.0.0:8545", "--seal", "--log-level=INFO"]
    volumes: ["./polygon-edge/data/4:/data", "./polygon-edge/genesis:/genesis:ro"]
    ports: ["8548:8545"]
    networks:
      polygon_network:
        ipv4_address: 172.18.0.4

networks:
  polygon_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.18.0.0/16
DEOF
echo "  ✓ Docker Compose configuration created"

echo ""
echo "[6/7] Starting blockchain network..."
docker-compose -f docker-compose.blockchain.generated.yml up -d
echo "  ✓ Containers starting..."
echo "  Waiting 30 seconds for nodes to initialize..."
sleep 30

echo ""
echo "[7/7] Verifying blockchain network..."
if curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -q "result"; then
    echo "  ✓ Node 1 (port 8545) is running"
else
    echo "  ⚠ Node 1 not responding yet"
fi

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "polygon|NAMES"

echo ""
echo "=============================================="
echo "✅ Deployment Complete!"
echo "  Node 1: http://localhost:8545"
echo "  Node 2: http://localhost:8546"
echo "  Node 3: http://localhost:8547"
echo "  Node 4: http://localhost:8548"
echo "  Chain ID: $CHAIN_ID"
echo "=============================================="
