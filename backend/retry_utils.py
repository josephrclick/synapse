"""
Retry utilities for handling transient failures in external services.
"""
import logging
import time
from functools import wraps
from typing import Callable, Any
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

logger = logging.getLogger(__name__)


# Define custom exceptions
class OllamaConnectionError(Exception):
    """Raised when Ollama service is unavailable."""
    pass


class ChromaDBConnectionError(Exception):
    """Raised when ChromaDB service is unavailable."""
    pass


def ollama_retry(func: Callable) -> Callable:
    """
    Decorator to retry Ollama operations with exponential backoff.
    """
    @wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        @retry(
            stop=stop_after_attempt(3),
            wait=wait_exponential(multiplier=1, min=2, max=10),
            retry=retry_if_exception_type((ConnectionError, OllamaConnectionError)),
            before_sleep=lambda retry_state: logger.warning(
                f"Ollama operation failed, retrying in {retry_state.next_action.sleep} seconds..."
            )
        )
        def _retry_func():
            try:
                return func(*args, **kwargs)
            except (ConnectionError, ConnectionRefusedError) as e:
                raise OllamaConnectionError(f"Failed to connect to Ollama: {e}")
            except Exception as e:
                if "connection" in str(e).lower():
                    raise OllamaConnectionError(f"Ollama connection error: {e}")
                raise
        
        return _retry_func()
    
    return wrapper


def chromadb_retry(func: Callable) -> Callable:
    """
    Decorator to retry ChromaDB operations with exponential backoff.
    """
    @wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        @retry(
            stop=stop_after_attempt(3),
            wait=wait_exponential(multiplier=1, min=2, max=10),
            retry=retry_if_exception_type((ConnectionError, ChromaDBConnectionError)),
            before_sleep=lambda retry_state: logger.warning(
                f"ChromaDB operation failed, retrying in {retry_state.next_action.sleep} seconds..."
            )
        )
        def _retry_func():
            try:
                return func(*args, **kwargs)
            except (ConnectionError, ConnectionRefusedError) as e:
                raise ChromaDBConnectionError(f"Failed to connect to ChromaDB: {e}")
            except Exception as e:
                if "connection" in str(e).lower() or "chroma" in str(e).lower():
                    raise ChromaDBConnectionError(f"ChromaDB connection error: {e}")
                raise
        
        return _retry_func()
    
    return wrapper