# CrowdfundChain Platform Deployment Guide

This comprehensive guide covers deploying the CrowdfundChain platform with Polygon blockchain integration, database setup, and production configuration.

## Quick Start

### Option 1: Automated Deployment Script

```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy to development environment
./deploy.sh development

# Deploy to production environment
./deploy.sh production
```

### Option 2: Docker Deployment

```bash
# Copy environment configuration
cp docker/.env.example docker/.env

# Edit configuration
nano docker/.env

# Start services
cd docker
docker-compose up -d

# With monitoring
docker-compose --profile monitoring up -d

# With polygon node
docker-compose --profile polygon up -d
```

## Deployment Components

### 1. System Requirements

**Minimum Requirements:**
- OS: Ubuntu 20.04+ or CentOS 8+
- RAM: 4GB (8GB recommended)
- Storage: 50GB SSD
- Network: 100Mbps connection

**Recommended Production:**
- RAM: 16GB
- Storage: 200GB NVMe SSD
- CPU: 8 cores
- Network: 1Gbps connection

### 2. Polygon Blockchain Setup

#### Mumbai Testnet (Development)
```bash
# Environment configuration
POLYGON_NETWORK=mumbai
POLYGON_RPC_URL=https://rpc-mumbai.matic.today
POLYGON_CHAIN_ID=80001
```

#### Polygon Mainnet (Production)
```bash
# Environment configuration  
POLYGON_NETWORK=polygon
POLYGON_RPC_URL=https://polygon-rpc.com
POLYGON_CHAIN_ID=137

# Optional: Run your own Polygon node
./deploy.sh production --with-polygon-node
```

#### Private Polygon Network (Enterprise)
```bash
# Custom network configuration
POLYGON_NETWORK=private
POLYGON_RPC_URL=http://your-private-node:8545
POLYGON_CHAIN_ID=1337
PRIVATE_KEY=your_deployment_private_key
```

### 3. Smart Contract Deployment

```bash
# Install Hardhat dependencies
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

# Configure environment
cp .env.example .env
# Edit .env with your configuration

# Deploy contracts to Mumbai testnet
npx hardhat run smart-contracts/deploy.js --network mumbai

# Deploy contracts to Polygon mainnet
npx hardhat run smart-contracts/deploy.js --network polygon

# Verify contracts on PolygonScan
npx hardhat verify --network mumbai <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

### 4. Database Configuration

#### PostgreSQL Setup
```bash
# Manual installation
sudo apt-get install postgresql-15 postgresql-contrib

# Create database
sudo -u postgres createdb crowdfundchain
sudo -u postgres createuser crowdfund_user

# Set password
sudo -u postgres psql -c "ALTER USER crowdfund_user PASSWORD 'your_password';"

# Grant permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE crowdfundchain TO crowdfund_user;"
```

#### Database Migration
```bash
# Push schema changes
npm run db:push

# Generate migrations (if using Drizzle migrations)
npm run db:generate
npm run db:migrate
```

### 5. IPFS Configuration

#### Local IPFS Node
```bash
# Install IPFS
wget https://dist.ipfs.io/go-ipfs/v0.20.0/go-ipfs_v0.20.0_linux-amd64.tar.gz
tar -xzf go-ipfs_v0.20.0_linux-amd64.tar.gz
sudo ./go-ipfs/install.sh

# Initialize and start
ipfs init
ipfs daemon
```

#### IPFS Service Configuration
```bash
# Create systemd service
sudo systemctl enable ipfs
sudo systemctl start ipfs

# Configure for production
ipfs config Addresses.API /ip4/127.0.0.1/tcp/5001
ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8080
```

## Environment Configuration

### Production Environment Variables

```bash
# Application
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/crowdfundchain

# Blockchain
POLYGON_NETWORK=polygon
POLYGON_RPC_URL=https://polygon-rpc.com
POLYGON_CHAIN_ID=137

# Smart Contracts (Update after deployment)
CAMPAIGN_FACTORY_ADDRESS=0x...
NFT_CERTIFICATE_ADDRESS=0x...
DAO_GOVERNANCE_ADDRESS=0x...

# IPFS
IPFS_API_URL=http://127.0.0.1:5001
IPFS_GATEWAY_URL=http://127.0.0.1:8080

# Security
JWT_SECRET=your_jwt_secret
SESSION_SECRET=your_session_secret

# Ethiopian Payment Gateways
TELEBIRR_API_KEY=your_api_key
CBE_API_KEY=your_api_key
AWASH_API_KEY=your_api_key
DASHEN_API_KEY=your_api_key
```

## Production Deployment Steps

### 1. Server Preparation
```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y curl wget git build-essential nginx certbot
```

### 2. Application Deployment
```bash
# Clone repository
git clone https://github.com/your-org/crowdfundchain.git
cd crowdfundchain

# Install dependencies
npm ci --production

# Build application
npm run build

# Configure environment
cp .env.example .env.production
# Edit .env.production with your settings
```

### 3. Process Management with PM2
```bash
# Install PM2
npm install -g pm2

# Start application
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save
pm2 startup
```

### 4. Nginx Configuration
```bash
# Configure reverse proxy
sudo cp nginx.conf /etc/nginx/sites-available/crowdfundchain
sudo ln -s /etc/nginx/sites-available/crowdfundchain /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 5. SSL Certificate
```bash
# Obtain SSL certificate
sudo certbot --nginx -d crowdfundchain.com -d www.crowdfundchain.com

# Setup auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

## Docker Deployment

### Complete Stack Deployment
```bash
# Clone repository
git clone https://github.com/your-org/crowdfundchain.git
cd crowdfundchain/docker

# Configure environment
cp .env.example .env
nano .env

# Start all services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f app
```

### Service Management
```bash
# View logs
docker-compose logs -f [service_name]

# Restart service
docker-compose restart [service_name]

# Update application
docker-compose pull app
docker-compose up -d app

# Backup database
docker-compose exec postgres pg_dump -U crowdfund_user crowdfundchain > backup.sql
```

## Monitoring and Maintenance

### Health Checks
```bash
# Application health
curl http://localhost:3000/api/stats

# Database health
pg_isready -h localhost -p 5432 -U crowdfund_user

# IPFS health  
curl http://localhost:5001/api/v0/version
```

### Log Management
```bash
# PM2 logs
pm2 logs crowdfundchain

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# System logs
journalctl -u crowdfundchain -f
```

### Backup Strategy
```bash
# Database backup
pg_dump crowdfundchain > backup_$(date +%Y%m%d).sql

# Application backup
tar -czf app_backup_$(date +%Y%m%d).tar.gz /var/www/crowdfundchain

# IPFS backup
tar -czf ipfs_backup_$(date +%Y%m%d).tar.gz ~/.ipfs
```

## Security Configuration

### Firewall Setup
```bash
# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### SSL/TLS Configuration
```bash
# Strong SSL configuration in Nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
```

## Troubleshooting

### Common Issues

#### Database Connection Failed
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check connection
psql -h localhost -U crowdfund_user -d crowdfundchain

# Check logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

#### Smart Contract Deployment Failed
```bash
# Check network configuration
npx hardhat console --network mumbai

# Verify RPC connection
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://rpc-mumbai.matic.today
```

#### IPFS Connection Issues
```bash
# Check IPFS daemon
ipfs swarm peers

# Reset IPFS configuration
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs daemon
```

### Performance Optimization

#### Database Tuning
```sql
-- PostgreSQL performance settings
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
SELECT pg_reload_conf();
```

#### Application Optimization
```bash
# PM2 cluster mode
pm2 start ecosystem.config.js --instances max

# Enable gzip compression in Nginx
gzip on;
gzip_types text/plain application/json application/javascript text/css;
```

## Scaling Considerations

### Horizontal Scaling
- Load balancer (HAProxy/Nginx)
- Multiple application instances
- Database read replicas
- Redis cluster for sessions

### Vertical Scaling
- Increase server resources
- Optimize database queries
- Implement caching strategies
- Use CDN for static assets

## Support and Maintenance

### Regular Maintenance Tasks
- Database vacuum and analyze
- Log rotation and cleanup
- Security updates
- SSL certificate renewal
- Backup verification

### Monitoring Alerts
- Application uptime
- Database performance
- Blockchain node sync status
- SSL certificate expiration
- Disk space usage

For additional support, refer to the project documentation or contact the development team.