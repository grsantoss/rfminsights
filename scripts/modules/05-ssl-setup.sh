#!/bin/bash
# RFM Insights - SSL Setup Module
# This module configures SSL certificates for RFM Insights

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          SSL SETUP                            "
echo "==================================================="
echo ""

# Start module log
log "Starting SSL setup"

# Check if Docker is running
log "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker and run this module again"
    exit 1
fi
success "Docker is running"

# Create SSL directory if it doesn't exist
log "Checking SSL directory..."
SSL_DIR="$PROJECT_ROOT/nginx/ssl"
if [ ! -d "$SSL_DIR" ]; then
    log "Creating SSL directory..."
    mkdir -p "$SSL_DIR"
fi
success "SSL directory ready"

# Check for existing certificates
log "Checking for existing SSL certificates..."
API_CERT="$SSL_DIR/api.crt"
API_KEY="$SSL_DIR/api.key"
FRONTEND_CERT="$SSL_DIR/frontend.crt"
FRONTEND_KEY="$SSL_DIR/frontend.key"

NEED_CERTS=false
if [ ! -f "$API_CERT" ] || [ ! -f "$API_KEY" ] || [ ! -f "$FRONTEND_CERT" ] || [ ! -f "$FRONTEND_KEY" ]; then
    NEED_CERTS=true
fi

if [ "$NEED_CERTS" = true ]; then
    log "SSL certificates missing. Generating self-signed certificates..."
    
    # Check for OpenSSL
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL not found. Please install OpenSSL and run this module again"
        exit 1
    fi
    
    # Generate API certificate
    log "Generating API certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$API_KEY" \
        -out "$API_CERT" \
        -subj "/CN=api.rfminsights.com.br/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:api.rfminsights.com.br,DNS:localhost"
    
    # Generate Frontend certificate
    log "Generating Frontend certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$FRONTEND_KEY" \
        -out "$FRONTEND_CERT" \
        -subj "/CN=app.rfminsights.com.br/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:app.rfminsights.com.br,DNS:localhost"
    
    # Check if certificates were generated successfully
    if [ -f "$API_CERT" ] && [ -f "$API_KEY" ] && [ -f "$FRONTEND_CERT" ] && [ -f "$FRONTEND_KEY" ]; then
        success "SSL certificates generated successfully"
    else
        error "Failed to generate SSL certificates"
        exit 1
    fi
else
    success "SSL certificates already exist"
fi

# Set proper permissions for SSL certificates
log "Setting proper permissions for SSL certificates..."
chmod 600 "$SSL_DIR"/*.key
chmod 644 "$SSL_DIR"/*.crt
success "SSL certificate permissions set"

# Verify certificates
log "Verifying SSL certificates..."
if [ -f "$API_CERT" ]; then
    log "API certificate info:"
    openssl x509 -in "$API_CERT" -noout -subject -issuer -dates | sed 's/^/  /'
fi

if [ -f "$FRONTEND_CERT" ]; then
    log "Frontend certificate info:"
    openssl x509 -in "$FRONTEND_CERT" -noout -subject -issuer -dates | sed 's/^/  /'
fi

success "SSL setup completed"
exit 0