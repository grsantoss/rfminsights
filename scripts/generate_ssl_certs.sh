#!/bin/bash
# RFM Insights - SSL Certificate Generation Script
# This script generates self-signed SSL certificates for development and testing

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO")
            echo -e "[$timestamp] [INFO] $message"
            ;;
        "SUCCESS")
            echo -e "[$timestamp] [${GREEN}SUCCESS${NC}] $message"
            ;;
        "WARNING")
            echo -e "[$timestamp] [${YELLOW}WARNING${NC}] $message"
            ;;
        "ERROR")
            echo -e "[$timestamp] [${RED}ERROR${NC}] $message"
            ;;
    esac
}

# Set the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Create SSL directory if it doesn't exist
if [ ! -d "$SSL_DIR" ]; then
    log "INFO" "Creating SSL directory..."
    mkdir -p "$SSL_DIR"
    log "SUCCESS" "SSL directory created at $SSL_DIR"
fi

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    log "ERROR" "OpenSSL is not installed. Please install OpenSSL to generate certificates."
    exit 1
fi

log "SUCCESS" "OpenSSL is installed. Proceeding with certificate generation."

# Function to generate a self-signed certificate
generate_self_signed_certificate() {
    local cert_name=$1
    local domain=$2
    local output_dir=$3
    
    local key_file="$output_dir/$cert_name.key"
    local crt_file="$output_dir/$cert_name.crt"
    
    # Check if certificate already exists
    if [ -f "$key_file" ] && [ -f "$crt_file" ]; then
        log "WARNING" "Certificate files for $cert_name already exist."
        read -p "Do you want to overwrite them? (Y/N): " overwrite
        if [ "$overwrite" != "Y" ] && [ "$overwrite" != "y" ]; then
            log "INFO" "Skipping certificate generation for $cert_name."
            return
        fi
    fi
    
    log "INFO" "Generating self-signed certificate for $domain..."
    
    # Generate private key and certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$crt_file" \
        -subj "/CN=$domain/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:$domain,DNS:localhost"
    
    if [ -f "$key_file" ] && [ -f "$crt_file" ]; then
        log "SUCCESS" "Certificate for $domain generated successfully."
        log "INFO" "Key file: $key_file"
        log "INFO" "Certificate file: $crt_file"
        
        # Set appropriate permissions
        chmod 644 "$crt_file"
        chmod 600 "$key_file"
        log "SUCCESS" "Permissions set for certificate files"
    else
        log "ERROR" "Failed to generate certificate files for $domain."
    fi
}

# Generate certificates for API and Frontend
generate_self_signed_certificate "api" "api.rfminsights.com.br" "$SSL_DIR"
generate_self_signed_certificate "frontend" "app.rfminsights.com.br" "$SSL_DIR"

# Inform user about next steps
log "SUCCESS" "SSL certificates have been generated."
log "INFO" "To use these certificates in a production environment, you should replace them with properly signed certificates from a trusted CA."

# Ask if user wants to restart Nginx to apply changes
read -p "Do you want to restart the Nginx container to apply the new certificates? (Y/N): " restart_nginx
if [ "$restart_nginx" = "Y" ] || [ "$restart_nginx" = "y" ]; then
    log "INFO" "Restarting Nginx container..."
    if docker-compose -f "$PROJECT_ROOT/docker-compose.yml" restart nginx-proxy; then
        log "SUCCESS" "Nginx container restarted successfully."
    else
        log "ERROR" "Failed to restart Nginx container."
        log "INFO" "Please restart the container manually using: docker-compose restart nginx-proxy"
    fi
else
    log "INFO" "Remember to restart the Nginx container to apply the new certificates."
    log "INFO" "You can do this by running: docker-compose restart nginx-proxy"
fi

log "SUCCESS" "SSL certificate setup completed."