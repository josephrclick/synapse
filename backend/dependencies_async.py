"""
Async dependency injection configuration for Capture-v3 backend.

This module contains async dependency functions used by FastAPI's dependency
injection system when async database mode is enabled.
"""
from typing import AsyncGenerator
from fastapi import Depends

from database_async import database
from repositories_async import DocumentRepositoryAsync


async def get_document_repository_async() -> AsyncGenerator[DocumentRepositoryAsync, None]:
    """
    Async dependency function to provide a DocumentRepositoryAsync instance.
    
    The database instance manages its own connection pool, so we just
    yield a repository configured with it.
    
    Yields:
        DocumentRepositoryAsync instance configured with the database
    """
    yield DocumentRepositoryAsync(database)