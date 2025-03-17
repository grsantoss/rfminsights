#!/bin/bash
# RFM Insights - Dependencies Module
# This module installs and verifies required dependencies

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          DEPENDENCIES SETUP                     "
echo "==================================================="
echo ""

# Start module log
log "Starting dependencies setup"

# Check for Docker
log "Checking for Docker..."
if ! command -v docker &> /dev/null; then
    warning "Docker not found"
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - Docker Desktop required
        error "Docker Desktop for Mac is required but not installed"
        log "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        exit 1
    else
        # Linux - attempt to install Docker
        warning "Attempting to install Docker..."
        
        # Update package lists
        log "Updating package lists..."
        apt update
        
        # Install prerequisites
        log "Installing prerequisites..."
        apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
        
        # Add Docker's official GPG key
        log "Adding Docker's GPG key..."
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Set up the Docker repository
        log "Setting up Docker repository..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package lists again
        log "Updating package lists with Docker repository..."
        apt update
        
        # Install Docker
        log "Installing Docker..."
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Start and enable Docker service
        log "Starting Docker service..."
        systemctl start docker
        systemctl enable docker
        
        # Verify Docker installation
        if command -v docker &> /dev/null; then
            success "Docker installed successfully"
            docker --version
        else
            error "Docker installation failed"
            exit 1
        fi
    fi
else
    success "Docker already installed"
    docker --version
fi

# Check for Docker Compose
log "Checking for Docker Compose..."
if ! docker compose version &> /dev/null; then
    warning "Docker Compose not found"
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - Docker Compose should be included with Docker Desktop
        error "Docker Compose should be included with Docker Desktop but was not found"
        log "Please reinstall Docker Desktop"
        exit 1
    else
        # Linux - install Docker Compose plugin
        warning "Attempting to install Docker Compose..."
        apt install -y docker-compose-plugin
        
        # Verify Docker Compose installation
        if docker compose version &> /dev/null; then
            success "Docker Compose installed successfully"
            docker compose version
        else
            error "Docker Compose installation failed"
            exit 1
        fi
    fi
else
    success "Docker Compose already installed"
    docker compose version
fi

# Check for OpenSSL (needed for certificate generation)
log "Checking for OpenSSL..."
if ! command -v openssl &> /dev/null; then
    warning "OpenSSL not found. Installing..."
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - use Homebrew
        if ! command -v brew &> /dev/null; then
            warning "Homebrew not found. OpenSSL installation requires Homebrew on macOS"
            read -p "Install Homebrew? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                success "Homebrew installed"
            else
                error "OpenSSL installation requires Homebrew"
                exit 1
            fi
        fi
        
        log "Installing OpenSSL via Homebrew..."
        brew install openssl
    else
        # Linux
        log "Installing OpenSSL via apt..."
        apt install -y openssl
    fi
    
    # Verify OpenSSL installation
    if command -v openssl &> /dev/null; then
        success "OpenSSL installed successfully"
        openssl version
    else
        error "OpenSSL installation failed"
        exit 1
    fi
else
    success "OpenSSL already installed"
    openssl version
fi

success "All dependencies verified"
exit 0