#!/bin/bash
# RFM Insights - Startup Script
# This script checks for required dependencies before starting the application

set -e

echo "[$(date)] Starting RFM Insights API startup checks..."

# Function to check if a Python package is installed
check_package() {
    local package=$1
    echo "[$(date)] Checking for package: $package"
    if python -c "import $package" &>/dev/null; then
        echo "[$(date)] ✅ Package $package is installed"
        return 0
    else
        echo "[$(date)] ❌ Package $package is NOT installed"
        return 1
    fi
}

# Check for critical packages
CRITICAL_PACKAGES=("reportlab" "fastapi" "uvicorn" "sqlalchemy" "openai" "pandas")
MISSING_PACKAGES=false

for package in "${CRITICAL_PACKAGES[@]}"; do
    if ! check_package "$package"; then
        MISSING_PACKAGES=true
        echo "[$(date)] 🔄 Attempting to install missing package: $package"
        pip install --no-cache-dir "$package"
        
        # Verify installation was successful
        if ! check_package "$package"; then
            echo "[$(date)] ⚠️ Failed to install $package. Application may not function correctly."
        else
            echo "[$(date)] ✅ Successfully installed $package"
        fi
    fi
done

# Run database health check to ensure PostgreSQL is ready before proceeding
echo "[$(date)] Running database health check..."
if [ -f "/app/scripts/db_healthcheck.py" ]; then
    chmod +x /app/scripts/db_healthcheck.py
    python /app/scripts/db_healthcheck.py --max-retries 30 --retry-interval 2
    DB_CHECK_RESULT=$?
    if [ $DB_CHECK_RESULT -eq 0 ]; then
        echo "[$(date)] ✅ Database health check passed. PostgreSQL is ready."
    else
        echo "[$(date)] ⚠️ Database health check failed. PostgreSQL may not be ready."
        # Only continue if the exit code is 1 (soft failure), exit if it's 2 (hard failure)
        if [ $DB_CHECK_RESULT -eq 2 ]; then
            echo "[$(date)] 🛑 Critical database connection error. Exiting..."
            exit 1
        else
            echo "[$(date)] ⚠️ Non-critical database issue. Continuing with caution..."
        fi
    fi
else
    echo "[$(date)] ⚠️ Database health check script not found. Falling back to basic check..."
    # Fallback to basic database connection check
    if python -c "import sqlalchemy; from sqlalchemy import create_engine; import os; engine = create_engine(os.getenv('DATABASE_URL')); conn = engine.connect(); conn.close()" &>/dev/null; then
        echo "[$(date)] ✅ Database connection successful"
    else
        echo "[$(date)] ⚠️ Could not connect to database. Check DATABASE_URL environment variable."
        # Don't fail here, as the application might handle this gracefully
    fi
fi

# Create health endpoint if it doesn't exist
if [ ! -f "/app/health_endpoint.py" ]; then
    echo "[$(date)] Creating health endpoint..."
    cat > /app/health_endpoint.py << 'EOL'
# Health endpoint for RFM Insights
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any
import sys
import pkg_resources

from backend.database import get_db
from backend.api_utils import success_response

router = APIRouter()

@router.get("/health", tags=["Health"])
async def health_check(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Health check endpoint for monitoring and container health checks"""
    # Check installed packages
    packages = {
        pkg.key: pkg.version for pkg in pkg_resources.working_set
    }
    
    # Check Python version
    python_version = sys.version
    
    # Check database connection
    db_status = "connected"
    try:
        # Just query something simple to verify connection
        db.execute("SELECT 1").fetchone()
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return success_response({
        "status": "healthy",
        "python_version": python_version,
        "database": db_status,
        "packages": {
            "reportlab": packages.get("reportlab", "not installed"),
            "fastapi": packages.get("fastapi", "not installed"),
            "sqlalchemy": packages.get("sqlalchemy", "not installed"),
            "openai": packages.get("openai", "not installed"),
        }
    })
EOL

    # Add import to main.py if not already there
    if ! grep -q "health_endpoint" /app/main.py; then
        echo "[$(date)] Adding health endpoint to main.py"
        # This is a simple approach - in a production environment, you might want to use a more robust method
        sed -i '/# Import routers/a from health_endpoint import router as health_router' /app/main.py
        sed -i '/app.include_router(auth_router, prefix=f"{api_v1_prefix}\/auth", tags=\["Authentication"\])/a app.include_router(health_router, tags=["Health"])' /app/main.py
    fi
fi

# Check if port 8000 is already in use and kill the process if needed
echo "[$(date)] Checking if port 8000 is already in use..."
if command -v lsof >/dev/null 2>&1; then
    # Using lsof if available (macOS, Linux)
    PORT_PID=$(lsof -ti:8000)
    if [ -n "$PORT_PID" ]; then
        echo "[$(date)] ⚠️ Port 8000 is already in use by PID $PORT_PID. Attempting to terminate..."
        kill -15 $PORT_PID 2>/dev/null || kill -9 $PORT_PID 2>/dev/null
        sleep 2
    fi
elif command -v netstat >/dev/null 2>&1; then
    # Using netstat as fallback
    if netstat -tuln | grep -q ":8000 "; then
        echo "[$(date)] ⚠️ Port 8000 is already in use. Please check running processes."
        # We can't easily get the PID with just netstat, so we'll just warn
    fi
fi

# Set up signal handling to ensure clean shutdown
cleanup() {
    echo "[$(date)] 🛑 Received shutdown signal. Cleaning up..."
    # Add any cleanup tasks here
    exit 0
}

# Register signal handlers
trap cleanup SIGTERM SIGINT

# All checks passed, start the application
echo "[$(date)] ✅ All dependency checks completed. Starting application..."
exec "$@"