#!/bin/bash
# CrowdfundChain Mobile Wallet Build Script

echo "========================================="
echo "📱 CrowdfundChain Mobile Wallet Builder"
echo "========================================="

cd /home/dltadmin/crowdfunding/mobile-wallet

# Check Node.js
echo "[→] Checking Node.js..."
node -v

# Install dependencies
echo "[→] Installing dependencies..."
npm install

# Build options
echo ""
echo "Build Options:"
echo "1. EAS Cloud Build (recommended for production)"
echo "2. Local Android Build (requires Android SDK)"
echo "3. Start Development Server"
echo ""

read -p "Select option (1/2/3): " option

case $option in
  1)
    echo "[→] Starting EAS Cloud Build..."
    npx eas build --platform android --profile preview
    ;;
  2)
    echo "[→] Starting Local Android Build..."
    npx expo prebuild --platform android --clean
    cd android && ./gradlew assembleRelease
    echo "APK: android/app/build/outputs/apk/release/app-release.apk"
    ;;
  3)
    echo "[→] Starting Development Server..."
    npx expo start --tunnel
    ;;
  *)
    echo "Invalid option"
    ;;
esac
