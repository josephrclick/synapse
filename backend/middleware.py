"""
Request middleware for the Synapse backend.
"""
import uuid
import time
import logging
from contextvars import ContextVar
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)

# Context variable to store request ID
_request_id_ctx_var: ContextVar[str] = ContextVar('request_id', default=None)

def get_request_id() -> str:
    """Get the current request ID from context."""
    return _request_id_ctx_var.get()


class RequestIDMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add a unique request ID to each request for tracing.
    """
    
    async def dispatch(self, request: Request, call_next):
        # Generate request ID
        request_id = str(uuid.uuid4())
        
        # Store in request state and context
        request.state.request_id = request_id
        _request_id_ctx_var.set(request_id)
        
        # Log request
        start_time = time.time()
        logger.info(f"[{request_id}] {request.method} {request.url.path}")
        
        try:
            # Process request
            response = await call_next(request)
            
            # Log response
            process_time = time.time() - start_time
            logger.info(
                f"[{request_id}] Completed in {process_time:.3f}s with status {response.status_code}"
            )
            
            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id
            
            return response
        finally:
            # Clear context
            _request_id_ctx_var.set(None)