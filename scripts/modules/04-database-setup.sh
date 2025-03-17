#!/bin/bash
# RFM Insights - Database Setup Module
# This module configures the PostgreSQL database for RFM Insights

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          DATABASE SETUP                        "
echo "==================================================="
echo ""

# Start module log
log "Starting database setup"

# Check if Docker is running
log "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker and run this module again"
    exit 1
fi
success "Docker is running"

# Check if PostgreSQL container is running
log "Checking if PostgreSQL container is running..."
PG_CONTAINER=$(docker ps --filter "name=rfminsights-postgres" --format "{{.Names}}")
if [ -z "$PG_CONTAINER" ]; then
    warning "PostgreSQL container is not running"
    
    # Check if container exists but is stopped
    STOPPED_PG=$(docker ps -a --filter "name=rfminsights-postgres" --format "{{.Names}}")
    if [ -n "$STOPPED_PG" ]; then
        warning "PostgreSQL container exists but is stopped"
        read -p "Do you want to start the PostgreSQL container? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Starting PostgreSQL container..."
            docker start rfminsights-postgres
            sleep 5  # Give container time to start
        else
            error "Database setup cannot continue without PostgreSQL container"
            exit 1
        fi
    else
        warning "PostgreSQL container does not exist"
        log "Please run the Docker setup module first"
        exit 1
    fi
fi
success "PostgreSQL container is running"

# Setup environment file
log "Setting up environment file..."
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE_FILE="$PROJECT_ROOT/.env.example"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE_FILE" ]; then
        log "Creating .env file from example..."
        cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
        
        # Update database connection for Docker
        log "Updating database connection string..."
        sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights|g' "$ENV_FILE"
        rm -f "$ENV_FILE.bak"  # Remove backup file on macOS
        
        success "Environment file created and configured"
    else
        error ".env.example file not found. Cannot create environment file"
        exit 1
    fi
else
    log "Checking database connection string in .env..."
    if grep -q "DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights" "$ENV_FILE"; then
        success "Database connection string is correctly configured"
    else
        warning "Database connection string may be incorrect in .env file"
        log "Updating database connection string..."
        sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights|g' "$ENV_FILE"
        rm -f "$ENV_FILE.bak"  # Remove backup file on macOS
        success "Database connection string updated"
    fi
fi

# Run database health check
log "Running database health check..."
DB_HEALTHCHECK_SCRIPT="$PROJECT_ROOT/scripts/db_healthcheck.py"
if [ -f "$DB_HEALTHCHECK_SCRIPT" ]; then
    log "Executing database health check script..."
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - use python3 explicitly
        python3 "$DB_HEALTHCHECK_SCRIPT" --max-retries 30 --retry-interval 2
    else
        # Linux - python command should be available
        python "$DB_HEALTHCHECK_SCRIPT" --max-retries 30 --retry-interval 2
    fi
    
    if [ $? -eq 0 ]; then
        success "Database health check passed"
    else
        error "Database health check failed. Please check PostgreSQL container logs"
        docker logs rfminsights-postgres
        exit 1
    fi
else
    warning "Database health check script not found at $DB_HEALTHCHECK_SCRIPT"
    log "Skipping database health check"
fi

# Run database migrations
log "Running database migrations..."
if [ -f "$PROJECT_ROOT/alembic.ini" ]; then
    log "Alembic configuration found. Running migrations..."
    
    # Check if we're running in a container or locally
    if [ -f "/.dockerenv" ]; then
        # Inside container
        log "Running migrations inside container..."
        cd "$PROJECT_ROOT" && alembic upgrade head
    else
        # Local execution - use docker exec
        log "Running migrations via docker exec..."
        docker exec rfminsights-api bash -c "cd /app && alembic upgrade head"
    fi
    
    if [ $? -eq 0 ]; then
        success "Database migrations completed successfully"
    else
        error "Database migrations failed"
        exit 1
    fi
else
    warning "Alembic configuration not found. Skipping migrations"
fi

success "Database setup completed"
exit 0