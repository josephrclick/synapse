"""
Dependency injection configuration for Capture-v3 backend.

This module contains dependency functions used by FastAPI's dependency
injection system to provide properly configured instances to endpoints.
"""
import sqlite3
from typing import Union, TYPE_CHECKING
from fastapi import Depends

from database import get_db, get_db_connection
from repositories import DocumentRepository
from config import settings

# Type checking imports
if TYPE_CHECKING:
    from repositories_async import DocumentRepositoryAsync

# Import async dependencies when feature flag is enabled
if settings.use_async_db:
    from database_async import database
    from repositories_async import DocumentRepositoryAsync
    from dependencies_async import get_document_repository_async


# For backward compatibility and gradual migration
def get_document_repository(db: sqlite3.Connection = Depends(get_db)) -> DocumentRepository:
    """
    Dependency function to provide a DocumentRepository instance.
    
    Args:
        db: Database connection from get_db dependency
        
    Returns:
        DocumentRepository instance configured with the database connection
    """
    return DocumentRepository(db)


# Unified dependency that returns appropriate repository based on feature flag
async def get_repository() -> Union[DocumentRepository, "DocumentRepositoryAsync"]:
    """
    Unified dependency that provides either sync or async repository
    based on the use_async_db feature flag.
    
    Returns:
        Either DocumentRepository or DocumentRepositoryAsync instance
    """
    if settings.use_async_db:
        return DocumentRepositoryAsync(database)
    else:
        # For sync mode, we get a connection and return sync repository
        # Note: This is a temporary solution during migration
        conn = get_db_connection()
        return DocumentRepository(conn)