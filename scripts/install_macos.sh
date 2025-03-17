#!/bin/bash
# RFM Insights - macOS Installation Script
# This script handles the complete installation process for macOS environments

set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
    exit 1
}

# Check status function
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$1 failed"
    fi
}

# Set project root directory and log file
PROJECT_ROOT=$(pwd)
LOG_FILE="$PROJECT_ROOT/install_macos.log"
touch "$LOG_FILE"

# Banner
echo ""
echo "==================================================="
echo "          RFM INSIGHTS - MACOS INSTALLATION     "
echo "==================================================="
echo ""

log "Starting RFM Insights installation on macOS"
log "Project directory: $PROJECT_ROOT"

# Step 1: Check for Docker
log "Checking for Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker not found. Please install Docker Desktop for Mac."
    log "Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi
success "Docker found"

# Step 2: Check for Docker Compose
log "Checking for Docker Compose..."
if ! docker compose version &> /dev/null; then
    error "Docker Compose not found. It should be included with Docker Desktop."
    exit 1
fi
success "Docker Compose found"

# Step 3: Check for Homebrew (optional but recommended)
log "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    warning "Homebrew not found. It's recommended for installing dependencies."
    log "Install with: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
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
        check_status "OpenSSL installation"
    else
        success "OpenSSL found"
    fi
fi

# Step 4: Create necessary directories
log "Creating directories..."
mkdir -p "$PROJECT_ROOT/nginx/ssl"
mkdir -p "$PROJECT_ROOT/nginx/logs"
mkdir -p "$PROJECT_ROOT/data"
mkdir -p "$PROJECT_ROOT/backups"
check_status "Directory creation"

# Step 5: Generate SSL certificates
log "Setting up SSL certificates..."
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

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

# Step 6: Setup environment file
log "Setting up environment file..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        log "Creating .env file from example..."
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        
        # Update database connection for Docker
        log "Updating database connection string..."
        sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights|g' "$PROJECT_ROOT/.env"
        rm -f "$PROJECT_ROOT/.env.bak"
        
        success "Environment file created and configured"
    else
        error ".env.example file not found. Cannot create environment file."
    fi
else
    log "Checking database connection string in .env..."
    if grep -q "DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights" "$PROJECT_ROOT/.env"; then
        success "Database connection string is correctly configured"
    else
        warning "Database connection string may be incorrect in .env file"
        log "Updating database connection string..."
        sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights|g' "$PROJECT_ROOT/.env"
        rm -f "$PROJECT_ROOT/.env.bak"
        success "Database connection string updated"
    fi
fi

# Step 7: Create health check file for frontend
log "Setting up health check endpoint..."
if [ ! -f "$PROJECT_ROOT/frontend/health.html" ]; then
    log "Creating health.html for frontend..."
    echo "<!DOCTYPE html><html><head><title>Health Check</title></head><body>OK</body></html>" > "$PROJECT_ROOT/frontend/health.html"
    success "Frontend health check file created"
fi

# Step 8: Start Docker services
log "Starting Docker services..."
log "Stopping any running containers..."
docker-compose down 2>/dev/null || true

log "Building and starting containers..."
docker-compose up -d --build
check_status "Docker services startup"

# Step 9: Verify services are running
log "Verifying services..."
sleep 10  # Give services time to start

log "Checking API service..."
if docker ps | grep -q "rfminsights-api"; then
    success "API service is running"
else
    warning "API service may not be running. Check with 'docker-compose logs api'"
fi

log "Checking frontend service..."
if docker ps | grep -q "rfminsights-frontend"; then
    success "Frontend service is running"
else
    warning "Frontend service may not be running. Check with 'docker-compose logs frontend'"
fi

log "Checking database service..."
if docker ps | grep -q "rfminsights-postgres"; then
    success "Database service is running"
else
    warning "Database service may not be running. Check with 'docker-compose logs postgres'"
fi

# Final instructions
success "RFM Insights installation completed successfully!"
log "You can access the application at: http://localhost"
log "API is available at: http://localhost:8000"
log "To view logs, run: docker-compose logs -f"
log "To stop the application, run: docker-compose down"
log "For troubleshooting, check the installation log: $LOG_FILE"