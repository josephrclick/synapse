"""
Async database module using databases library with aiosqlite.
This module provides async database operations with connection pooling.
"""
import logging
from pathlib import Path
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from databases import Database

from .config import settings

logger = logging.getLogger(__name__)

# Create database URL for SQLite with aiosqlite driver
DATABASE_URL = f"sqlite+aiosqlite:///{settings.sqlite_db_path}"

# Create global database instance with connection pooling
# force_rollback is enabled in test mode for transaction isolation
database = Database(
    DATABASE_URL,
    force_rollback=settings.testing
)


async def init_db():
    """
    Initializes the database and creates tables if they don't exist.
    This is intended to be called once on application startup.
    Uses async operations for non-blocking initialization.
    Note: The database connection should already be established before calling this.
    """
    logger.info(f"Initializing async database at {settings.sqlite_db_path}...")
    
    # Ensure directory exists
    db_path = Path(settings.sqlite_db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        # Enable WAL mode for better concurrent access
        result = await database.fetch_one("PRAGMA journal_mode=WAL")
        logger.info(f"SQLite journal mode set to: {result[0] if result else 'unknown'}")
        
        # Set busy timeout to 30 seconds to handle concurrent access
        await database.execute("PRAGMA busy_timeout=30000")
        logger.info("SQLite busy timeout set to 30 seconds")
        
        # Enable foreign key constraints
        await database.execute("PRAGMA foreign_keys = ON")
        
        # Create documents table with all required fields including audit columns
        await database.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            source_url TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            processing_error TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            max_retries INTEGER NOT NULL DEFAULT 3,
            next_attempt_at TEXT,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
        )
        """)
        
        # Create indexes for frequently queried fields
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_documents_status 
        ON documents(status)
        """)
        
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_documents_type 
        ON documents(type)
        """)
        
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_documents_created_at 
        ON documents(created_at)
        """)
        
        # Create document_links table for many-to-many relationships
        await database.execute("""
        CREATE TABLE IF NOT EXISTS document_links (
            source_doc_id TEXT NOT NULL,
            target_doc_id TEXT NOT NULL,
            PRIMARY KEY (source_doc_id, target_doc_id),
            FOREIGN KEY (source_doc_id) REFERENCES documents(id) ON DELETE CASCADE,
            FOREIGN KEY (target_doc_id) REFERENCES documents(id) ON DELETE CASCADE
        )
        """)
        
        # Create indexes for document_links
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_document_links_source 
        ON document_links(source_doc_id)
        """)
        
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_document_links_target 
        ON document_links(target_doc_id)
        """)
        
        # Create document_tags table for storing tags
        await database.execute("""
        CREATE TABLE IF NOT EXISTS document_tags (
            document_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            PRIMARY KEY (document_id, tag),
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
        """)
        
        # Create index for tag lookups
        await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_document_tags_tag 
        ON document_tags(tag)
        """)
        
        logger.info("Async database initialized successfully.")
        
    except Exception as e:
        logger.error(f"Async database initialization failed: {e}", exc_info=True)
        raise


@asynccontextmanager
async def get_database() -> AsyncGenerator[Database, None]:
    """
    Async context manager for database access.
    The global database instance manages its own connection pool,
    so we just yield it directly.
    """
    yield database