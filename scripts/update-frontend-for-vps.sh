#!/bin/bash

# CrowdfundChain Frontend Build & Deploy Script for VPS
# Run this from the project root directory (where package.json is)

set -e

echo "=== CrowdfundChain Frontend Rebuild Script ==="
echo ""

# Configuration - UPDATE THESE PATHS TO MATCH YOUR VPS
PROJECT_DIR="${PROJECT_DIR:-/home/dltadmin/crowdfunding}"
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/crowdfundchain/frontend}"
DJANGO_DIR="${DJANGO_DIR:-/home/dltadmin/crowdfunding/django-issuer-platform}"

# Step 1: Update Django CORS settings
echo "[1/4] Updating Django CORS settings..."
if [ -f "$DJANGO_DIR/issuer_platform/settings.py" ]; then
    if ! grep -q "196.188.63.167" "$DJANGO_DIR/issuer_platform/settings.py"; then
        echo "Adding VPS IP to CORS_ALLOWED_ORIGINS..."
        sed -i "s/CORS_ALLOWED_ORIGINS = \[/CORS_ALLOWED_ORIGINS = [\n    'http:\/\/196.188.63.167',\n    'http:\/\/196.188.63.167:80',/" "$DJANGO_DIR/issuer_platform/settings.py"
        echo "CORS settings updated."
    else
        echo "CORS settings already include VPS IP."
    fi
else
    echo "WARNING: Django settings.py not found at $DJANGO_DIR/issuer_platform/settings.py"
fi

# Step 2: Check project directory
echo ""
echo "[2/4] Checking project structure..."
cd "$PROJECT_DIR"

if [ ! -f "client/index.html" ]; then
    echo "ERROR: client/index.html not found in $PROJECT_DIR"
    echo "Make sure you synced the full project including client/ folder"
    exit 1
fi

if [ ! -f "package.json" ]; then
    echo "ERROR: package.json not found in $PROJECT_DIR"
    exit 1
fi

echo "Project structure OK"

# Step 3: Build frontend using the VPS-specific vite config
echo ""
echo "[3/4] Building frontend..."

# Install dependencies if needed
npm install --legacy-peer-deps 2>/dev/null || npm install

# Use the VPS build config if it exists, otherwise create one inline
if [ -f "vite.build.config.js" ]; then
    echo "Using vite.build.config.js..."
    npx vite build --config vite.build.config.js
else
    echo "Creating inline vite config for production build..."
    cat > /tmp/vite.prod.config.js << 'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = process.cwd();

export default defineConfig({
  plugins: [react()],
  root: path.resolve(projectRoot, "client"),
  build: {
    outDir: path.resolve(projectRoot, "dist"),
    emptyOutDir: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(projectRoot, "client/src"),
      "@shared": path.resolve(projectRoot, "shared"),
      "@assets": path.resolve(projectRoot, "attached_assets"),
    },
  },
});
EOF
    npx vite build --config /tmp/vite.prod.config.js
fi

echo "Frontend built successfully."

# Step 4: Deploy to web directory
echo ""
echo "[4/4] Deploying to $DEPLOY_DIR..."

# Create deploy dir if it doesn't exist
mkdir -p "$DEPLOY_DIR"

# Clear old files and copy new
rm -rf "$DEPLOY_DIR"/*
cp -r dist/* "$DEPLOY_DIR/"

# Set permissions
chown -R www-data:www-data "$DEPLOY_DIR" 2>/dev/null || echo "Ownership change skipped (may need sudo)"

# Restart services
echo ""
echo "Restarting services..."
systemctl reload nginx 2>/dev/null || sudo systemctl reload nginx 2>/dev/null || echo "Nginx reload skipped"

# Restart Django if running via systemd
if systemctl is-active --quiet crowdfundchain 2>/dev/null; then
    systemctl restart crowdfundchain
    echo "Django service restarted."
fi

echo ""
echo "=== Deployment Complete ==="
echo "Frontend is now live at http://196.188.63.167/"
echo ""
echo "If you see a blank page, check:"
echo "1. Browser console (F12) for JavaScript errors"
echo "2. Network tab for failed API requests"
echo "3. Django logs: journalctl -u crowdfundchain -f"
