# RFM Insights - Main Application

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import time

# Import routers
from backend.rfm_api import router as rfm_router
from backend.marketplace import router as marketplace_router
from backend.auth_routes import router as auth_router

# Create FastAPI app
app = FastAPI(
    title="RFM Insights API",
    description="API para análise RFM e geração de insights de marketing",
    version="1.0.0",
    docs_url=None,  # Disable default docs
    redoc_url=None  # Disable default redoc
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Error handling middleware
@app.middleware("http")
async def error_handling_middleware(request: Request, call_next):
    start_time = time.time()
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        return response
    except Exception as e:
        process_time = time.time() - start_time
        error_detail = str(e)
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal Server Error",
                "detail": error_detail,
                "path": request.url.path
            }
        )

# Include routers
app.include_router(rfm_router, prefix="/api/rfm", tags=["RFM Analysis"])
app.include_router(marketplace_router, prefix="/api/marketplace", tags=["Marketplace"])
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])

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
    return {"message": "RFM Insights API", "docs": "/docs"}

# Run the application
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)