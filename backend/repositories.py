"""
Repository pattern implementation for Capture-v3 backend.

This module contains repository classes that abstract data access logic,
providing a clean separation between the API layer and database implementation.
"""
import sqlite3
from typing import List, Dict, Tuple, Optional
from collections import defaultdict
import logging
import uuid
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class DocumentRepository:
    """Repository for document data access operations."""
    
    def __init__(self, connection: sqlite3.Connection):
        """
        Initialize the repository with a database connection.
        
        Args:
            connection: SQLite database connection
        """
        self.connection = connection
    
    def create(self, doc_data: Dict) -> Dict:
        """
        Create a new document in the database.
        
        Args:
            doc_data: Document data including type, title, content, etc.
            
        Returns:
            The created document as a dictionary
        """
        doc_id = str(uuid.uuid4())
        current_time = datetime.utcnow().isoformat()
        
        cursor = self.connection.cursor()
        cursor.execute("""
            INSERT INTO documents 
            (id, type, title, content, source_url, status, retry_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            doc_id,
            doc_data["type"],
            doc_data["title"],
            doc_data["content"],
            doc_data.get("source_url"),
            "pending",
            0,
            current_time,
            current_time
        ))
        
        # Insert tags if provided
        if "tags" in doc_data and doc_data["tags"]:
            for tag in doc_data["tags"]:
                cursor.execute("""
                    INSERT INTO document_tags (document_id, tag)
                    VALUES (?, ?)
                """, (doc_id, tag))
        
        # Link to another document if specified
        if "link_to_doc_id" in doc_data and doc_data["link_to_doc_id"]:
            cursor.execute("""
                INSERT INTO document_links (source_doc_id, target_doc_id)
                VALUES (?, ?)
            """, (doc_id, doc_data["link_to_doc_id"]))
        
        self.connection.commit()
        
        # Fetch and return the created document
        return self.get_by_id(doc_id)
    
    def get_by_id(self, doc_id: str) -> Optional[Dict]:
        """
        Retrieve a document by its ID.
        
        Args:
            doc_id: Document ID
            
        Returns:
            Document as a dictionary or None if not found
        """
        cursor = self.connection.cursor()
        cursor.execute("SELECT * FROM documents WHERE id = ?", (doc_id,))
        row = cursor.fetchone()
        
        if not row:
            return None
        
        doc = dict(row)
        
        # Fetch tags
        cursor.execute("SELECT tag FROM document_tags WHERE document_id = ?", (doc_id,))
        doc["tags"] = [row[0] for row in cursor.fetchall()]
        
        # Fetch linked document IDs
        cursor.execute("""
            SELECT target_doc_id FROM document_links WHERE source_doc_id = ?
            UNION
            SELECT source_doc_id FROM document_links WHERE target_doc_id = ?
        """, (doc_id, doc_id))
        doc["linked_document_ids"] = [row[0] for row in cursor.fetchall()]
        
        return doc
    
    def get_all(self, limit: int = 20, offset: int = 0) -> Tuple[List[Dict], int]:
        """
        Retrieve documents with pagination.
        
        Args:
            limit: Maximum number of documents to return
            offset: Number of documents to skip
            
        Returns:
            Tuple of (documents list, total count)
        """
        cursor = self.connection.cursor()
        
        # Get total count
        cursor.execute("SELECT COUNT(*) FROM documents")
        total = cursor.fetchone()[0]
        
        # Get paginated documents
        cursor.execute("""
            SELECT * FROM documents 
            ORDER BY created_at DESC 
            LIMIT ? OFFSET ?
        """, (limit, offset))
        
        documents = []
        doc_ids = []
        
        # First, collect all documents and their IDs
        for row in cursor.fetchall():
            doc = dict(row)
            documents.append(doc)
            doc_ids.append(doc["id"])
        
        # If no documents, return early
        if not doc_ids:
            return documents, total
        
        # Bulk fetch all tags for the retrieved documents
        placeholders = ','.join('?' * len(doc_ids))
        cursor.execute(f"""
            SELECT document_id, tag 
            FROM document_tags 
            WHERE document_id IN ({placeholders})
        """, doc_ids)
        
        # Map tags to documents using defaultdict
        tags_map = defaultdict(list)
        for doc_id, tag in cursor.fetchall():
            tags_map[doc_id].append(tag)
        
        # Bulk fetch all links for the retrieved documents
        cursor.execute(f"""
            SELECT source_doc_id, target_doc_id 
            FROM document_links 
            WHERE source_doc_id IN ({placeholders}) 
               OR target_doc_id IN ({placeholders})
        """, doc_ids + doc_ids)  # doc_ids twice for both conditions
        
        # Map links to documents
        links_map = defaultdict(set)  # Use set to avoid duplicates
        for source_id, target_id in cursor.fetchall():
            if source_id in doc_ids:
                links_map[source_id].add(target_id)
            if target_id in doc_ids:
                links_map[target_id].add(source_id)
        
        # Attach tags and links to documents
        for doc in documents:
            doc_id = doc["id"]
            doc["tags"] = tags_map.get(doc_id, [])
            doc["linked_document_ids"] = list(links_map.get(doc_id, []))
        
        return documents, total
    
    def update_status(self, doc_id: str, status: str, 
                     processing_error: Optional[str] = None) -> None:
        """
        Update document processing status.
        
        Args:
            doc_id: Document ID
            status: New status
            processing_error: Error message if status is 'failed'
        """
        cursor = self.connection.cursor()
        current_time = datetime.utcnow().isoformat()
        
        if processing_error:
            # Get current retry count for exponential backoff
            cursor.execute("SELECT retry_count FROM documents WHERE id = ?", (doc_id,))
            result = cursor.fetchone()
            retry_count = result[0] if result else 0
            
            # Exponential backoff: 1 min, 2 min, 4 min, 8 min, etc.
            # Cap at 10 minutes (600 seconds)
            delay_seconds = min(60 * (2 ** retry_count), 600)
            next_attempt = datetime.utcnow() + timedelta(seconds=delay_seconds)
            next_attempt_str = next_attempt.isoformat()
            
            cursor.execute("""
                UPDATE documents 
                SET status = ?, processing_error = ?, last_error = ?, 
                    updated_at = ?, retry_count = retry_count + 1,
                    next_attempt_at = ?
                WHERE id = ?
            """, (status, processing_error, processing_error, current_time, next_attempt_str, doc_id))
        else:
            cursor.execute("""
                UPDATE documents 
                SET status = ?, updated_at = ?
                WHERE id = ?
            """, (status, current_time, doc_id))
        
        self.connection.commit()
    
    def get_failed_documents_for_retry(self, max_retries: int = 3) -> List[Dict]:
        """
        Get documents that failed but can be retried.
        
        Args:
            max_retries: Maximum number of retries allowed
            
        Returns:
            List of documents eligible for retry
        """
        cursor = self.connection.cursor()
        current_time = datetime.utcnow().isoformat()
        
        cursor.execute("""
            SELECT * FROM documents 
            WHERE status = 'failed' 
            AND retry_count < ?
            AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
            ORDER BY created_at ASC
            LIMIT 50
        """, (max_retries, current_time))
        
        documents = []
        for row in cursor.fetchall():
            documents.append(dict(row))
        
        return documents