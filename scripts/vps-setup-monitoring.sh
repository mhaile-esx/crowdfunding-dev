#!/bin/bash
set -e

echo "=============================================="
echo "CrowdfundChain Monitoring Stack Setup"
echo "Prometheus + Grafana (Docker)"
echo "=============================================="

INSTALL_DIR="/opt/crowdfundchain/monitoring"
DATA_DIR="/var/lib/crowdfundchain/monitoring"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "Creating directories..."
mkdir -p $INSTALL_DIR
mkdir -p $DATA_DIR/prometheus
mkdir -p $DATA_DIR/grafana
chmod -R 777 $DATA_DIR/grafana

echo "Creating Prometheus configuration..."
cat > $INSTALL_DIR/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'crowdfundchain'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - /etc/prometheus/alerts/*.yml

scrape_configs:
  #============================================================================
  # PROMETHEUS SELF-MONITORING
  #============================================================================
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  #============================================================================
  # DJANGO ISSUER PLATFORM
  #============================================================================
  - job_name: 'django-api'
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: /metrics
    scrape_timeout: 10s

  #============================================================================
  # POLYGON EDGE BLOCKCHAIN NODES (4-Node IBFT Cluster)
  # JSON-RPC endpoints for blockchain monitoring
  #============================================================================
  - job_name: 'polygon-edge-nodes'
    static_configs:
      - targets:
          - 'host.docker.internal:8545'   # Node 1 (Primary)
          - 'host.docker.internal:8546'   # Node 2
          - 'host.docker.internal:8547'   # Node 3
          - 'host.docker.internal:8548'   # Node 4
        labels:
          network: 'polygon-edge'
          chain_id: '100'
    metrics_path: /debug/metrics/prometheus
    scrape_timeout: 10s

  # Polygon Edge JSON-RPC Health (custom blackbox-style)
  - job_name: 'polygon-edge-rpc'
    static_configs:
      - targets:
          - 'host.docker.internal:8545'
        labels:
          node: 'node1'
          role: 'primary'
      - targets:
          - 'host.docker.internal:8546'
        labels:
          node: 'node2'
          role: 'validator'
      - targets:
          - 'host.docker.internal:8547'
        labels:
          node: 'node3'
          role: 'validator'
      - targets:
          - 'host.docker.internal:8548'
        labels:
          node: 'node4'
          role: 'validator'

  #============================================================================
  # KEYCLOAK SSO/AUTHENTICATION
  #============================================================================
  - job_name: 'keycloak'
    static_configs:
      - targets: ['host.docker.internal:8080']
    metrics_path: /metrics
    scrape_timeout: 10s

  #============================================================================
  # POSTGRESQL DATABASE
  #============================================================================
  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']
        labels:
          database: 'crowdfundchain'

  #============================================================================
  # REDIS CACHE & CELERY BROKER
  #============================================================================
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
        labels:
          role: 'celery-broker'

  #============================================================================
  # CELERY WORKERS (if using flower)
  #============================================================================
  - job_name: 'celery'
    static_configs:
      - targets: ['host.docker.internal:5555']
    metrics_path: /metrics
    scrape_timeout: 10s

  #============================================================================
  # NGINX REVERSE PROXY
  #============================================================================
  - job_name: 'nginx'
    static_configs:
      - targets: ['host.docker.internal:9113']
    metrics_path: /metrics

  #============================================================================
  # SYSTEM METRICS (Node Exporter)
  #============================================================================
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'vps'
EOF

# Create alerts directory and basic alerts
mkdir -p $INSTALL_DIR/alerts
cat > $INSTALL_DIR/alerts/crowdfundchain.yml << 'EOF'
groups:
  - name: crowdfundchain_alerts
    rules:
      # Django API down
      - alert: DjangoAPIDown
        expr: up{job="django-api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Django API is down"
          description: "Django API has been down for more than 1 minute."

      # Polygon Edge node down
      - alert: PolygonEdgeNodeDown
        expr: up{job="polygon-edge-nodes"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Polygon Edge node is down"
          description: "One or more Polygon Edge validators are unreachable."

      # PostgreSQL down
      - alert: PostgreSQLDown
        expr: up{job="postgresql"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL database is down"
          description: "PostgreSQL has been unreachable for more than 1 minute."

      # Redis down
      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Redis is down"
          description: "Redis cache/Celery broker is unreachable."

      # Keycloak down
      - alert: KeycloakDown
        expr: up{job="keycloak"} == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Keycloak SSO is down"
          description: "Keycloak authentication server is unreachable."

      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes."

      # Low disk space
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space"
          description: "Less than 20% disk space remaining on root partition."
EOF

echo "Creating Grafana provisioning configuration..."
mkdir -p $INSTALL_DIR/grafana/provisioning/datasources
mkdir -p $INSTALL_DIR/grafana/provisioning/dashboards

cat > $INSTALL_DIR/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

cat > $INSTALL_DIR/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'CrowdfundChain'
    orgId: 1
    folder: 'CrowdfundChain'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

mkdir -p $INSTALL_DIR/grafana/dashboards

cat > $INSTALL_DIR/grafana/dashboards/crowdfundchain-overview.json << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "mappings": [],
          "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {"colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "pluginVersion": "10.0.0",
      "targets": [{"expr": "up{job=\"django\"}", "legendFormat": "Django API", "refId": "A"}],
      "title": "Django API Status",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {"defaults": {"color": {"mode": "palette-classic"}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}}},
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {"colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "count(up{job=~\"polygon-edge.*\"} == 1)", "legendFormat": "Active Nodes", "refId": "A"}],
      "title": "Polygon Edge Nodes",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {"defaults": {"color": {"mode": "palette-classic"}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}}},
      "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
      "id": 3,
      "options": {"colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "up{job=\"postgresql\"}", "legendFormat": "PostgreSQL", "refId": "A"}],
      "title": "PostgreSQL Status",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {"defaults": {"color": {"mode": "palette-classic"}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}}},
      "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
      "id": 4,
      "options": {"colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "up{job=\"redis\"}", "legendFormat": "Redis", "refId": "A"}],
      "title": "Redis Status",
      "type": "stat"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {"defaults": {"unit": "percent"}},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "id": 5,
      "targets": [{"expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "CPU Usage", "refId": "A"}],
      "title": "System CPU Usage",
      "type": "timeseries"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {"defaults": {"unit": "bytes"}},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
      "id": 6,
      "targets": [{"expr": "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes", "legendFormat": "Used Memory", "refId": "A"}, {"expr": "node_memory_MemTotal_bytes", "legendFormat": "Total Memory", "refId": "B"}],
      "title": "System Memory Usage",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["crowdfundchain"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timepicker": {},
  "timezone": "",
  "title": "CrowdfundChain Overview",
  "uid": "crowdfundchain-overview",
  "version": 1,
  "weekStart": ""
}
EOF

echo "Creating Docker Compose file..."
cat > $INSTALL_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-CrowdfundChain2024!}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    restart: unless-stopped
    environment:
      - DATA_SOURCE_NAME=postgresql://${POSTGRES_USER:-crowdfund}:${POSTGRES_PASSWORD:-crowdfund123}@host.docker.internal:5432/${POSTGRES_DB:-crowdfundchain}?sslmode=disable
    ports:
      - "9187:9187"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    restart: unless-stopped
    environment:
      - REDIS_ADDR=redis://host.docker.internal:6379
    ports:
      - "9121:9121"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

networks:
  monitoring:
    driver: bridge
EOF

echo "Creating environment file..."

# Prompt for credentials if not provided as environment variables
if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
    echo ""
    read -sp "Enter Grafana admin password (leave empty for auto-generated): " GRAFANA_ADMIN_PASSWORD
    echo ""
    if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)
        echo "Generated Grafana password: $GRAFANA_ADMIN_PASSWORD"
    fi
fi

if [ -z "$POSTGRES_USER" ]; then
    read -p "Enter PostgreSQL username [crowdfund]: " POSTGRES_USER
    POSTGRES_USER=${POSTGRES_USER:-crowdfund}
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    read -sp "Enter PostgreSQL password: " POSTGRES_PASSWORD
    echo ""
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo "ERROR: PostgreSQL password is required"
        exit 1
    fi
fi

if [ -z "$POSTGRES_DB" ]; then
    read -p "Enter PostgreSQL database name [crowdfundchain]: " POSTGRES_DB
    POSTGRES_DB=${POSTGRES_DB:-crowdfundchain}
fi

cat > $INSTALL_DIR/.env << EOF
# Grafana Admin Password (auto-generated or user-provided)
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# PostgreSQL Connection
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
EOF

chmod 600 $INSTALL_DIR/.env
echo "Environment file created with secure permissions (600)"

echo "Creating systemd service..."
cat > /etc/systemd/system/crowdfundchain-monitoring.service << EOF
[Unit]
Description=CrowdfundChain Monitoring Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

echo "Starting monitoring stack..."
cd $INSTALL_DIR
docker-compose pull
docker-compose up -d

systemctl daemon-reload
systemctl enable crowdfundchain-monitoring.service

echo ""
echo "=============================================="
echo "Monitoring Stack Installation Complete!"
echo "=============================================="
echo ""
echo "Services:"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
echo ""
echo "Grafana Login:"
echo "  Username: admin"
echo "  Password: (stored in $INSTALL_DIR/.env)"
echo ""
echo "Configuration files:"
echo "  $INSTALL_DIR/prometheus.yml"
echo "  $INSTALL_DIR/docker-compose.yml"
echo "  $INSTALL_DIR/.env"
echo ""
echo "Commands:"
echo "  Start:   docker-compose -f $INSTALL_DIR/docker-compose.yml up -d"
echo "  Stop:    docker-compose -f $INSTALL_DIR/docker-compose.yml down"
echo "  Logs:    docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f"
echo "  Status:  docker-compose -f $INSTALL_DIR/docker-compose.yml ps"
echo ""
echo "To update Grafana password, edit: $INSTALL_DIR/.env"
echo "=============================================="
