#!/bin/bash

echo "🧪 Testing Multi-Node Deployment System..."

# Test deployment script execution
echo "1. Testing deployment script permissions..."
if [ -x "./deploy-multi-node.sh" ]; then
    echo "✅ Deployment script is executable"
else
    echo "❌ Deployment script is not executable"
    chmod +x deploy-multi-node.sh
    echo "✅ Fixed deployment script permissions"
fi

# Test Docker Compose file validity
echo "2. Testing Docker Compose configuration..."
if docker-compose -f docker/docker-compose.multi-node.yml config > /dev/null 2>&1; then
    echo "✅ Docker Compose configuration is valid"
else
    echo "❌ Docker Compose configuration has errors"
    docker-compose -f docker/docker-compose.multi-node.yml config
fi

# Test Keycloak configuration
echo "3. Testing Keycloak realm configuration..."
if [ -f "docker/keycloak/realm-export.json" ]; then
    echo "✅ Keycloak realm configuration exists"
    
    # Validate JSON
    if jq empty docker/keycloak/realm-export.json > /dev/null 2>&1; then
        echo "✅ Keycloak realm JSON is valid"
    else
        echo "❌ Keycloak realm JSON is invalid"
    fi
else
    echo "❌ Keycloak realm configuration missing"
fi

# Test Nginx configuration
echo "4. Testing Nginx configuration..."
if [ -f "docker/nginx/nginx.conf" ]; then
    echo "✅ Nginx configuration exists"
    
    # Test nginx config syntax (if nginx is available)
    if command -v nginx >/dev/null 2>&1; then
        if nginx -t -c $(pwd)/docker/nginx/nginx.conf > /dev/null 2>&1; then
            echo "✅ Nginx configuration syntax is valid"
        else
            echo "⚠️  Nginx configuration syntax may have issues"
        fi
    else
        echo "ℹ️  Nginx not available for syntax testing"
    fi
else
    echo "❌ Nginx configuration missing"
fi

# Test environment configuration
echo "5. Testing environment configuration..."
if [ -f ".env.example" ]; then
    echo "✅ Environment example file exists"
else
    echo "❌ Environment example file missing"
fi

# Test application health endpoint
echo "6. Testing application health endpoint..."
if curl -s http://localhost:5000/api/keycloak/health > /dev/null 2>&1; then
    echo "✅ Application health endpoint is accessible"
    curl -s http://localhost:5000/api/keycloak/health | jq .
else
    echo "ℹ️  Application may not be running (this is expected)"
fi

# Test smart contract deployment script
echo "7. Testing smart contract deployment..."
if [ -f "smart-contracts/deploy/deploy-enhanced.js" ]; then
    echo "✅ Enhanced smart contract deployment script exists"
else
    echo "❌ Enhanced smart contract deployment script missing"
fi

echo "🎯 Multi-node deployment test complete!"
echo ""
echo "📋 Deployment Commands:"
echo "  ./deploy-multi-node.sh              # Deploy development environment"
echo "  ./deploy-multi-node.sh production   # Deploy production environment"
echo ""
echo "🔧 Management Commands:"
echo "  docker-compose -f docker/docker-compose.multi-node.yml ps        # Check status"
echo "  docker-compose -f docker/docker-compose.multi-node.yml logs -f   # View logs"
echo "  docker-compose -f docker/docker-compose.multi-node.yml down      # Stop services"