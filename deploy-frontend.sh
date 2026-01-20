#!/bin/bash

VPS_IP="196.188.63.167"
VPS_USER="root"

echo "=== CrowdfundChain Frontend Deployment ==="

echo "[1/4] Building frontend for production..."
npm run build

if [ ! -d "dist/public" ]; then
  echo "Error: Build failed - dist/public not found"
  exit 1
fi

echo "[2/4] Creating frontend archive..."
tar -czf frontend-build.tar.gz -C dist/public .

echo "[3/4] Deploying to VPS..."
scp frontend-build.tar.gz ${VPS_USER}@${VPS_IP}:/tmp/

ssh ${VPS_USER}@${VPS_IP} << 'EOF'
  mkdir -p /var/www/crowdfundchain/frontend
  rm -rf /var/www/crowdfundchain/frontend/*
  tar -xzf /tmp/frontend-build.tar.gz -C /var/www/crowdfundchain/frontend/
  rm /tmp/frontend-build.tar.gz
  
  chown -R www-data:www-data /var/www/crowdfundchain/frontend
  chmod -R 755 /var/www/crowdfundchain/frontend
  
  echo "Frontend files deployed to /var/www/crowdfundchain/frontend/"
  ls -la /var/www/crowdfundchain/frontend/
EOF

echo "[4/4] Cleaning up local files..."
rm -f frontend-build.tar.gz

echo ""
echo "=== Frontend deployment complete! ==="
echo "Now update nginx config to serve the frontend."
