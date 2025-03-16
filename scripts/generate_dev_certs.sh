#!/bin/bash
# RFM Insights - Development SSL Certificate Generation Script
# This script generates self-signed SSL certificates for development environment

# Set the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Create SSL directory if it doesn't exist
if [ ! -d "$SSL_DIR" ]; then
    echo "Creating SSL directory..."
    mkdir -p "$SSL_DIR"
    echo "SSL directory created at $SSL_DIR"
fi

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    echo "ERROR: OpenSSL is not installed. Please install OpenSSL to generate certificates."
    exit 1
fi

echo "OpenSSL is installed. Proceeding with certificate generation."

# Function to generate a self-signed certificate
generate_self_signed_certificate() {
    local cert_name=$1
    local domain=$2
    local output_dir=$3
    
    local key_file="$output_dir/$cert_name.key"
    local crt_file="$output_dir/$cert_name.crt"
    
    echo "Generating self-signed certificate for $domain..."
    
    # Generate private key and certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$crt_file" \
        -subj "/CN=$domain/O=RFM Insights/C=BR" \
        -addext "subjectAltName=DNS:$domain,DNS:localhost"
    
    if [ -f "$key_file" ] && [ -f "$crt_file" ]; then
        echo "Certificate for $domain generated successfully."
        echo "Key file: $key_file"
        echo "Certificate file: $crt_file"
        
        # Set appropriate permissions
        chmod 644 "$crt_file"
        chmod 600 "$key_file"
        echo "Permissions set for certificate files"
    else
        echo "ERROR: Failed to generate certificate files for $domain."
    fi
}

# Generate certificates for API and Frontend
generate_self_signed_certificate "api" "api.rfminsights.com.br" "$SSL_DIR"
generate_self_signed_certificate "frontend" "app.rfminsights.com.br" "$SSL_DIR"

echo "SSL certificates have been generated successfully."
echo "You can now start your Docker containers with: docker-compose up -d"