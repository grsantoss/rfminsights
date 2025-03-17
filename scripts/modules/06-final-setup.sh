#!/bin/bash
# RFM Insights - Final Setup Module
# This module finalizes the RFM Insights setup and verifies everything is working correctly

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          FINAL SETUP                           "
echo "==================================================="
echo ""

# Start module log
log "Starting final setup"

# Check if Docker is running
log "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker and run this module again"
    exit 1
fi
success "Docker is running"

# Check if all containers are running
log "Checking container status..."
REQUIRED_CONTAINERS=("rfminsights-postgres" "rfminsights-api" "rfminsights-frontend" "rfminsights-nginx")
MISSING_CONTAINERS=false

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if ! docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        warning "Container $container is not running"
        MISSING_CONTAINERS=true
    else
        success "Container $container is running"
    fi
done

if [ "$MISSING_CONTAINERS" = true ]; then
    warning "Some containers are not running"
    log "Attempting to start all containers with docker-compose..."
    
    # Navigate to project root and start containers
    cd "$PROJECT_ROOT"
    docker-compose up -d
    
    # Check again after starting
    sleep 5
    STILL_MISSING=false
    for container in "${REQUIRED_CONTAINERS[@]}"; do
        if ! docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            warning "Container $container is still not running"
            STILL_MISSING=true
        else
            success "Container $container is now running"
        fi
    done
    
    if [ "$STILL_MISSING" = true ]; then
        warning "Some containers could not be started"
        log "Please check docker-compose logs for more information:"
        log "  cd $PROJECT_ROOT && docker-compose logs"
    else
        success "All containers are now running"
    fi
else
    success "All required containers are running"
fi

# Verify API health endpoint
log "Checking API health endpoint..."
API_HEALTH="https://localhost:8000/health"
if curl -k -s "$API_HEALTH" | grep -q "status.*ok"; then
    success "API health check passed"
else
    warning "API health check failed"
    log "The API may still be starting up. Please check manually:"
    log "  curl -k $API_HEALTH"
fi

# Create a simple health check script for future use
log "Creating health check script..."
HEALTH_SCRIPT="$PROJECT_ROOT/scripts/health_check.sh"
cat > "$HEALTH_SCRIPT" << 'EOF'
#!/bin/bash
# RFM Insights - Health Check Script

echo "Checking RFM Insights services..."

# Check Docker containers
echo "\nContainer Status:"
docker ps --filter "name=rfminsights" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check API health
echo "\nAPI Health:"
curl -k -s https://localhost:8000/health
echo

echo "\nIf all services are running, you can access RFM Insights at:"
echo "  - Frontend: https://localhost"
echo "  - API: https://localhost:8000"
EOF

chmod +x "$HEALTH_SCRIPT"
success "Health check script created at $HEALTH_SCRIPT"

# Final instructions
log "RFM Insights installation is complete"
log "You can now access the application at:"
log "  - Frontend: https://localhost"
log "  - API: https://localhost:8000"
log "\nTo check the status of your installation in the future, run:"
log "  $HEALTH_SCRIPT"

# Return success
exit 0