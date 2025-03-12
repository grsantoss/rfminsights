# RFM Insights - Main Application

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import time
import logging

# Import logging configuration and environment validation
from config.logging_config import setup_logging
from config.env_validator import check_environment

# Import monitoring module
from backend.monitoring import initialize_monitoring, MonitoringMiddleware, RequestContext

# Setup application logging
logger = setup_logging(debug_mode=os.getenv("DEBUG", "False").lower() == "true")

# Validate environment variables
check_environment(exit_on_error=os.getenv("ENVIRONMENT", "development").lower() == "production")

# Initialize monitoring system
initialize_monitoring()

# Import routers
from backend.rfm_api import router as rfm_router
from backend.marketplace import router as marketplace_router
from backend.auth_routes import router as auth_router

# Import API utilities and response schemas
from backend.api_utils import get_api_prefix, http_exception_handler, exception_handler
from backend.schemas import ResponseError

# Create FastAPI app
app = FastAPI(
    title="RFM Insights API",
    description="API para análise RFM e geração de insights de marketing",
    version="1.0.0",
    docs_url=None,  # Disable default docs
    redoc_url=None  # Disable default redoc
)

# Configure CORS
origins = ["http://localhost:3000", "https://rfminsights.com.br"]
if os.getenv("ENVIRONMENT", "development").lower() == "development":
    origins = ["*"]  # Allow all origins in development

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Add rate limiting middleware for authentication endpoints
from backend.middleware import RateLimiter, RequestValidator

# Configure rate limiting (5 requests per minute, block for 5 minutes)
app.add_middleware(RateLimiter, rate_limit=5, time_window=60, block_time=300)

# Add request validation middleware
app.add_middleware(RequestValidator)

# Add monitoring middleware
app.add_middleware(MonitoringMiddleware)

# Error handling middleware
@app.middleware("http")
async def error_handling_middleware(request: Request, call_next):
    start_time = time.time()
    
    # Set request context for monitoring
    request_id = RequestContext.generate_request_id()
    RequestContext.set("ip_address", request.client.host if request.client else "unknown")
    RequestContext.set("user_agent", request.headers.get("user-agent", "unknown"))
    RequestContext.set("endpoint", request.url.path)
    RequestContext.set("http_method", request.method)
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        response.headers["X-API-Version"] = "v1"  # Add API version header
        response.headers["X-Request-ID"] = request_id  # Add request ID header
        
        # Set response status in context
        RequestContext.set("status_code", response.status_code)
        RequestContext.set("response_time", process_time)
        
        # Log request completion with enhanced context
        access_logger = logging.getLogger('api.access')
        access_logger.info(
            f"Request completed: {request.method} {request.url.path} - Status: {response.status_code} - Time: {process_time:.4f}s - ID: {request_id}",
            extra=RequestContext.get_all()
        )
        return response
    except Exception as e:
        process_time = time.time() - start_time
        error_detail = str(e)
        
        # Set error information in context
        RequestContext.set("error", error_detail)
        RequestContext.set("error_type", e.__class__.__name__)
        RequestContext.set("response_time", process_time)
        
        # Log the error with enhanced context
        logger.error(
            f"Error processing request: {request.method} {request.url.path} - Error: {error_detail} - ID: {request_id}", 
            exc_info=True,
            extra=RequestContext.get_all()
        )
        
        # Use standardized error response format
        error_response = ResponseError(
            message="Internal Server Error",
            error_code="INTERNAL_ERROR",
            details={
                "path": request.url.path,
                "error_type": e.__class__.__name__,
                "error_detail": error_detail if os.getenv("DEBUG", "False").lower() == "true" else None
            }
        )
        
        return JSONResponse(
            status_code=500,
            content=error_response.dict()
        )

# Add exception handlers for standardized error responses
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, exception_handler)

# Include routers with versioned API paths
api_v1_prefix = get_api_prefix("v1")
app.include_router(rfm_router, prefix=f"{api_v1_prefix}/rfm", tags=["RFM Analysis"])
app.include_router(marketplace_router, prefix=f"{api_v1_prefix}/marketplace", tags=["Marketplace"])
app.include_router(auth_router, prefix=f"{api_v1_prefix}/auth", tags=["Authentication"])

# Add legacy routes for backward compatibility
app.include_router(rfm_router, prefix="/api/rfm", tags=["RFM Analysis (Legacy)"], include_in_schema=False)
app.include_router(marketplace_router, prefix="/api/marketplace", tags=["Marketplace (Legacy)"], include_in_schema=False)
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication (Legacy)"], include_in_schema=False)

# Custom documentation routes
@app.get("/docs", include_in_schema=False)
async def custom_swagger_ui_html():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=app.title + " - Documentação API",
        oauth2_redirect_url=app.swagger_ui_oauth2_redirect_url,
        swagger_js_url="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.9.0/swagger-ui-bundle.js",
        swagger_css_url="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.9.0/swagger-ui.css",
    )

@app.get("/redoc", include_in_schema=False)
async def redoc_html():
    return get_redoc_html(
        openapi_url=app.openapi_url,
        title=app.title + " - ReDoc",
        redoc_js_url="https://cdn.jsdelivr.net/npm/redoc@next/bundles/redoc.standalone.js",
    )

# Serve static files
app.mount("/static", StaticFiles(directory="frontend"), name="static")

# Root endpoint redirects to docs
@app.get("/", include_in_schema=False)
async def root():
    return {
        "message": "RFM Insights API", 
        "docs": "/docs",
        "version": "1.0.0",
        "api_version": "v1",
        "endpoints": {
            "current": f"{get_api_prefix()}",
            "legacy": "/api"
        }
    }

# Run the application
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)