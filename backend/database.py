import sqlite3
from contextlib import contextmanager
from typing import Generator
import logging
from pathlib import Path

from .config import settings

logger = logging.getLogger(__name__)


def get_db_connection() -> sqlite3.Connection:
    """Gets a new database connection with row_factory configured."""
    # Use check_same_thread=False to allow connections across threads
    conn = sqlite3.connect(settings.sqlite_db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row  # Allows accessing columns by name
    
    # Apply critical pragmas for each connection
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode=WAL")  # Better concurrent access
    conn.execute("PRAGMA busy_timeout=30000")  # 30 second timeout
    
    return conn


def init_db():
    """
    Initializes the database and creates tables if they don't exist.
    This is intended to be called once on application startup.
    """
    logger.info(f"Initializing database at {settings.sqlite_db_path}...")
    
    # Ensure directory exists
    db_path = Path(settings.sqlite_db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Enable WAL mode for better concurrent access
            cursor.execute("PRAGMA journal_mode=WAL")
            result = cursor.fetchone()
            logger.info(f"SQLite journal mode set to: {result[0] if result else 'unknown'}")
            
            # Set busy timeout to 30 seconds to handle concurrent access
            cursor.execute("PRAGMA busy_timeout=30000")
            logger.info("SQLite busy timeout set to 30 seconds")
            
            # Create documents table with all required fields including audit columns
            cursor.execute("""
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
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_documents_status 
            ON documents(status)
            """)
            
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_documents_type 
            ON documents(type)
            """)
            
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_documents_created_at 
            ON documents(created_at)
            """)
            
            # Create document_links table for many-to-many relationships
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS document_links (
                source_doc_id TEXT NOT NULL,
                target_doc_id TEXT NOT NULL,
                PRIMARY KEY (source_doc_id, target_doc_id),
                FOREIGN KEY (source_doc_id) REFERENCES documents(id) ON DELETE CASCADE,
                FOREIGN KEY (target_doc_id) REFERENCES documents(id) ON DELETE CASCADE
            )
            """)
            
            # Create indexes for document_links
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_document_links_source 
            ON document_links(source_doc_id)
            """)
            
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_document_links_target 
            ON document_links(target_doc_id)
            """)
            
            # Create document_tags table for storing tags
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS document_tags (
                document_id TEXT NOT NULL,
                tag TEXT NOT NULL,
                PRIMARY KEY (document_id, tag),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
            )
            """)
            
            # Create index for tag lookups
            cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_document_tags_tag 
            ON document_tags(tag)
            """)
            
            conn.commit()
            
        logger.info("Database initialized successfully.")
        
    except sqlite3.Error as e:
        logger.error(f"Database initialization failed: {e}", exc_info=True)
        raise


def get_db() -> Generator[sqlite3.Connection, None, None]:
    """
    FastAPI dependency to get a DB connection for a single request.
    Ensures the connection is closed after the request is finished.
    """
    conn = None
    try:
        conn = get_db_connection()
        yield conn
    finally:
        if conn:
            conn.close()
