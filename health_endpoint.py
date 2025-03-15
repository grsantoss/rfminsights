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