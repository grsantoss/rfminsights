# RFM Insights - Middleware Module

from fastapi import Request, HTTPException, status
from typing import Dict, List, Callable, Optional
import time
import logging
from collections import defaultdict

# Setup logger
logger = logging.getLogger('app.middleware')

# Rate limiting middleware for authentication endpoints
class RateLimiter:
    """
    Rate limiting middleware to prevent brute force attacks
    Tracks requests by IP address and blocks excessive requests
    """
    def __init__(self, 
                 rate_limit: int = 5, 
                 time_window: int = 60,
                 block_time: int = 300):
        """
        Initialize rate limiter
        
        Args:
            rate_limit: Maximum number of requests allowed in the time window
            time_window: Time window in seconds
            block_time: Time to block in seconds after exceeding rate limit
        """
        self.rate_limit = rate_limit
        self.time_window = time_window
        self.block_time = block_time
        self.requests: Dict[str, List[float]] = defaultdict(list)
        self.blocked_ips: Dict[str, float] = {}
        
    async def __call__(self, request: Request, call_next: Callable):
        """
        Middleware implementation
        
        Args:
            request: FastAPI request object
            call_next: Next middleware or endpoint handler
        """
        # Get client IP
        client_ip = self._get_client_ip(request)
        path = request.url.path
        
        # Only apply rate limiting to authentication endpoints
        if not self._is_auth_endpoint(path):
            return await call_next(request)
        
        # Check if IP is blocked
        if client_ip in self.blocked_ips:
            block_time = self.blocked_ips[client_ip]
            current_time = time.time()
            
            # If block time has expired, remove from blocked list
            if current_time > block_time:
                del self.blocked_ips[client_ip]
                logger.info(f"Unblocked IP {client_ip} after timeout period")
            else:
                # Calculate remaining block time
                remaining = int(block_time - current_time)
                logger.warning(f"Blocked request from {client_ip} to {path} (remaining block time: {remaining}s)")
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Too many requests. Please try again in {remaining} seconds."
                )
        
        # Clean up old requests
        self._cleanup_old_requests(client_ip)
        
        # Check rate limit
        if len(self.requests[client_ip]) >= self.rate_limit:
            # Block the IP
            self.blocked_ips[client_ip] = time.time() + self.block_time
            logger.warning(f"Blocked IP {client_ip} for {self.block_time} seconds due to rate limit exceeded")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Please try again later."
            )
        
        # Add current request timestamp
        self.requests[client_ip].append(time.time())
        
        # Process the request
        return await call_next(request)
    
    def _get_client_ip(self, request: Request) -> str:
        """
        Get client IP address from request headers or connection info
        
        Args:
            request: FastAPI request object
        """
        # Try to get IP from X-Forwarded-For header (when behind proxy/load balancer)
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            # Get the first IP in the chain
            return forwarded_for.split(",")[0].strip()
        
        # Fallback to direct client IP
        return request.client.host if request.client else "unknown"
    
    def _cleanup_old_requests(self, client_ip: str) -> None:
        """
        Remove requests older than the time window
        
        Args:
            client_ip: Client IP address
        """
        if client_ip in self.requests:
            current_time = time.time()
            self.requests[client_ip] = [
                timestamp for timestamp in self.requests[client_ip]
                if current_time - timestamp < self.time_window
            ]
    
    def _is_auth_endpoint(self, path: str) -> bool:
        """
        Check if the path is an authentication endpoint
        
        Args:
            path: Request path
        """
        auth_endpoints = [
            "/api/auth/token",
            "/api/auth/register",
            "/api/auth/password-reset"
        ]
        return any(path.startswith(endpoint) for endpoint in auth_endpoints)


# Input validation middleware
class RequestValidator:
    """
    Middleware for additional request validation
    Performs basic sanity checks on incoming requests
    """
    async def __call__(self, request: Request, call_next: Callable):
        """
        Middleware implementation
        
        Args:
            request: FastAPI request object
            call_next: Next middleware or endpoint handler
        """
        # Get request content type
        content_type = request.headers.get("content-type", "")
        
        # For JSON requests, validate content length
        if "application/json" in content_type:
            content_length = request.headers.get("content-length", "0")
            try:
                if int(content_length) > 10 * 1024 * 1024:  # 10MB limit
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="Request body too large"
                    )
            except ValueError:
                pass
        
        # Process the request
        return await call_next(request)