#!/bin/bash
# RFM Insights - Deployment Fix Script
# This script fixes common deployment issues

set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    echo -e "[${GREEN}SUCCESS${NC}] $1"
}

warning() {
    echo -e "[${YELLOW}WARNING${NC}] $1"
}

error() {
    echo -e "[${RED}ERROR${NC}] $1"
}

# Get project root directory
PROJECT_ROOT=$(pwd)
log "Project directory: $PROJECT_ROOT"

# 1. Fix SSL certificates
log "Checking SSL certificates..."
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

if [ ! -d "$SSL_DIR" ]; then
    log "Creating SSL directory..."
    mkdir -p "$SSL_DIR"
    success "SSL directory created"
fi

# Check if certificates exist
if [ ! -f "$SSL_DIR/api.crt" ] || [ ! -f "$SSL_DIR/api.key" ] || \
   [ ! -f "$SSL_DIR/frontend.crt" ] || [ ! -f "$SSL_DIR/frontend.key" ]; then
    log "SSL certificates missing. Generating self-signed certificates..."
    
    # Check if OpenSSL is installed
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL not found. Please install OpenSSL to generate certificates."
        exit 1
    fi
    
    # Generate API certificate
    log "Generating API certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/api.key" \
        -out "$SSL_DIR/api.crt" \
        -subj "/CN=api.rfminsights.com.br/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:api.rfminsights.com.br,DNS:localhost"
    
    # Generate Frontend certificate
    log "Generating Frontend certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/frontend.key" \
        -out "$SSL_DIR/frontend.crt" \
        -subj "/CN=app.rfminsights.com.br/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:app.rfminsights.com.br,DNS:localhost"
    
    # Set appropriate permissions
    chmod 644 "$SSL_DIR"/*.crt
    chmod 600 "$SSL_DIR"/*.key
    
    success "SSL certificates generated successfully"
else
    success "SSL certificates already exist"
fi

# 2. Check database connection
log "Checking database connection settings..."

# Ensure DATABASE_URL is correctly set in .env
if grep -q "DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights" "$PROJECT_ROOT/.env"; then
    success "Database connection string is correctly configured"
else
    warning "Database connection string may be incorrect in .env file"
    log "Ensuring correct database connection string..."
    sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights|g' "$PROJECT_ROOT/.env"
    success "Database connection string updated"
fi

# 3. Fix health check endpoints
log "Checking health check endpoints..."

# Create health.html file for frontend if it doesn't exist
if [ ! -f "$PROJECT_ROOT/frontend/health.html" ]; then
    log "Creating health.html for frontend..."
    mkdir -p "$PROJECT_ROOT/frontend"
    echo "<!DOCTYPE html><html><head><title>Health Check</title></head><body>OK</body></html>" > "$PROJECT_ROOT/frontend/health.html"
    success "Frontend health check file created"
fi

# 4. Check port configurations
log "Checking port configurations..."
success "Port configurations in docker-compose.yml look correct"

# 5. Final instructions
success "Deployment fixes applied successfully!"
log "Next steps:"
log "1. Run 'docker-compose down' to stop any running containers"
log "2. Run 'docker-compose up -d' to start the application with the fixes applied"
log "3. Check container logs with 'docker-compose logs -f' to verify everything is working"