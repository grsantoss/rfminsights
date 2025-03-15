#!/bin/bash

# RFM Insights - macOS Setup Script
# This script handles the setup process specifically for macOS environments

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check status function
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$1"
        exit 1
    fi
}

# Banner
echo ""
echo "==================================================="
echo "          RFM INSIGHTS - MACOS SETUP             "
echo "==================================================="
echo ""

# Get project root directory
PROJECT_ROOT=$(pwd)
log "Project directory: $PROJECT_ROOT"

# Check for Docker
log "Checking for Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker not found. Please install Docker Desktop for Mac."
    echo "Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi
success "Docker found"

# Check for Docker Compose
log "Checking for Docker Compose..."
if ! docker compose version &> /dev/null; then
    error "Docker Compose not found. It should be included with Docker Desktop."
    exit 1
fi
success "Docker Compose found"

# Check for Homebrew (optional but recommended)
log "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    warning "Homebrew not found. It's recommended for installing dependencies."
    echo "Install with: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    read -p "Continue without Homebrew? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    success "Homebrew found"
    
    # Install OpenSSL if needed
    if ! command -v openssl &> /dev/null; then
        log "Installing OpenSSL via Homebrew..."
        brew install openssl
        check_status "OpenSSL installed"
    else
        success "OpenSSL found"
    fi
fi

# Create necessary directories
log "Creating directories..."
mkdir -p "$PROJECT_ROOT/nginx/ssl"
mkdir -p "$PROJECT_ROOT/nginx/logs"
mkdir -p "$PROJECT_ROOT/data"
mkdir -p "$PROJECT_ROOT/backups"
check_status "Directories created"

# Generate SSL certificates
log "Generating SSL certificates..."
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Check if certificates already exist
if [ -f "$SSL_DIR/server.crt" ] && [ -f "$SSL_DIR/server.key" ]; then
    warning "SSL certificates already exist. Skipping generation."
else
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" \
        -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=RFM Insights/OU=IT/CN=app.rfminsights.com.br" \
        -addext "subjectAltName=DNS:app.rfminsights.com.br,DNS:api.rfminsights.com.br"
    
    check_status "SSL certificates generated"
    
    # Set permissions
    chmod 644 "$SSL_DIR/server.crt"
    chmod 600 "$SSL_DIR/server.key"
    check_status "Certificate permissions set"
fi

# Check and configure .env file
log "Configuring .env file..."
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        success ".env file created from example"
    else
        error ".env.example file not found"
        exit 1
    fi
else
    warning ".env file already exists. Checking configuration..."
fi

# Generate secure JWT key if needed
JWT_SECRET=$(grep JWT_SECRET_KEY "$ENV_FILE" | cut -d '=' -f2)
if [ -z "$JWT_SECRET" ] || [ "$JWT_SECRET" == "your-secret-key-should-be-very-long-and-secure" ]; then
    NEW_JWT_SECRET=$(openssl rand -hex 32)
    sed -i.bak "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$NEW_JWT_SECRET/" "$ENV_FILE"
    rm "$ENV_FILE.bak" # Remove backup file created by sed on macOS
    success "JWT key generated"
fi

# Check Nginx configuration
log "Checking Nginx configuration..."
FRONTEND_CONF="$PROJECT_ROOT/nginx/frontend.conf"

if [ ! -f "$FRONTEND_CONF" ]; then
    error "frontend.conf file not found. Please run the installation script first."
    exit 1
fi
success "Nginx configuration verified"

# Add hosts entries (requires sudo)
log "Would you like to add app.rfminsights.com.br and api.rfminsights.com.br to your hosts file?"
read -p "This requires sudo access (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "127.0.0.1 app.rfminsights.com.br api.rfminsights.com.br" | sudo tee -a /etc/hosts > /dev/null
    check_status "Hosts entries added"
fi

# Final instructions
success "macOS setup completed successfully!"
echo ""
log "You can now start RFM Insights with: docker-compose up -d"
echo ""
log "Access the application at:"
echo "  - Frontend: http://localhost or https://app.rfminsights.com.br"
echo "  - API: http://localhost:8000 or https://api.rfminsights.com.br"
echo ""