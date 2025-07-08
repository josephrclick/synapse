"""
Authentication module for API key validation.
Uses FastAPI dependency injection pattern.
"""
from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader

from .config import settings

# Define the API key header name
API_KEY_NAME = "X-API-KEY"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=True)


async def get_api_key(api_key: str = Security(api_key_header)) -> str:
    """
    Validates the API key from the request header.
    
    Args:
        api_key: The API key extracted from the X-API-KEY header
        
    Returns:
        The validated API key
        
    Raises:
        HTTPException: 401 if the API key is invalid or missing
    """
    if api_key != settings.internal_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API Key",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    return api_key