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

# Check for database connection
echo "[$(date)] Checking database connection..."
if python -c "import sqlalchemy; from sqlalchemy import create_engine; import os; engine = create_engine(os.getenv('DATABASE_URL')); conn = engine.connect(); conn.close()" &>/dev/null; then
    echo "[$(date)] ✅ Database connection successful"
else
    echo "[$(date)] ⚠️ Could not connect to database. Check DATABASE_URL environment variable."
    # Don't fail here, as the application might handle this gracefully
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

from .backend.database import get_db
from .backend.api_utils import success_response

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

# All checks passed, start the application
echo "[$(date)] ✅ All dependency checks completed. Starting application..."
exec "$@"