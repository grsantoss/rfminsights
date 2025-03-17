#!/bin/bash
# RFM Insights - Docker Setup Module
# This module configures Docker containers for RFM Insights

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          DOCKER SETUP                          "
echo "==================================================="
echo ""

# Start module log
log "Starting Docker setup"

# Check if Docker is running
log "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    warning "Docker is not running"
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - Docker Desktop needs to be started
        warning "Please start Docker Desktop and try again"
        read -p "Press Enter after starting Docker Desktop..." -n 1 -r
        echo
        
        # Check again
        if ! docker info &> /dev/null; then
            error "Docker is still not running. Please start Docker Desktop and run this script again"
            exit 1
        fi
    else
        # Linux - try to start Docker service
        warning "Attempting to start Docker service..."
        systemctl start docker
        
        # Check again
        if ! docker info &> /dev/null; then
            error "Failed to start Docker service. Please check Docker installation"
            exit 1
        fi
    fi
fi
success "Docker is running"

# Create necessary directories
log "Creating necessary directories..."
directories=(
    "$PROJECT_ROOT/nginx/ssl"
    "$PROJECT_ROOT/nginx/logs"
    "$PROJECT_ROOT/data"
    "$PROJECT_ROOT/backups"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
done
success "Directory structure created"

# Check if docker-compose.yml exists
log "Checking for docker-compose.yml..."
if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    error "docker-compose.yml not found in project root"
    exit 1
fi
success "docker-compose.yml found"

# Check for existing containers
log "Checking for existing containers..."
EXISTING_CONTAINERS=$(docker ps -a --filter "name=rfminsights" --format "{{.Names}}")
if [ -n "$EXISTING_CONTAINERS" ]; then
    warning "Existing RFM Insights containers found:"
    echo "$EXISTING_CONTAINERS"
    read -p "Do you want to stop and remove existing containers? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Stopping and removing existing containers..."
        docker-compose -f "$PROJECT_ROOT/docker-compose.yml" down
        success "Existing containers removed"
    else
        warning "Keeping existing containers. This may cause conflicts"
    fi
fi

# Pull latest images
log "Pulling latest Docker images..."
docker-compose -f "$PROJECT_ROOT/docker-compose.yml" pull
success "Docker images pulled successfully"

# Build and start containers
log "Building and starting containers..."
docker-compose -f "$PROJECT_ROOT/docker-compose.yml" up -d --build

# Check if containers started successfully
log "Verifying containers are running..."
sleep 5  # Give containers time to start
RUNNING_CONTAINERS=$(docker ps --filter "name=rfminsights" --format "{{.Names}}")
if [ -z "$RUNNING_CONTAINERS" ]; then
    error "Failed to start containers. Check docker-compose logs for details"
    docker-compose -f "$PROJECT_ROOT/docker-compose.yml" logs
    exit 1
fi

# List running containers
log "Running containers:"
echo "$RUNNING_CONTAINERS"
success "Docker containers started successfully"

exit 0