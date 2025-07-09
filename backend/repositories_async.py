"""
Async repository pattern implementation for Synapse backend.

This module contains async repository classes that use the databases library
for non-blocking database operations with connection pooling.
"""
from typing import List, Dict, Tuple, Optional
from collections import defaultdict
import logging
import uuid
from datetime import datetime, timedelta

from databases import Database

logger = logging.getLogger(__name__)


class DocumentRepositoryAsync:
    """Async repository for document data access operations."""
    
    def __init__(self, database: Database):
        """
        Initialize the repository with an async database instance.
        
        Args:
            database: Databases instance with connection pool
        """
        self.database = database
    
    async def create(self, doc_data: Dict) -> Dict:
        """
        Create a new document in the database.
        
        Args:
            doc_data: Document data including type, title, content, etc.
            
        Returns:
            The created document as a dictionary
        """
        doc_id = str(uuid.uuid4())
        current_time = datetime.utcnow().isoformat()
        
        # Insert main document
        query = """
            INSERT INTO documents 
            (id, type, title, content, source_url, status, retry_count, created_at, updated_at)
            VALUES (:id, :type, :title, :content, :source_url, :status, :retry_count, :created_at, :updated_at)
        """
        values = {
            "id": doc_id,
            "type": doc_data["type"],
            "title": doc_data["title"],
            "content": doc_data["content"],
            "source_url": doc_data.get("source_url"),
            "status": "pending",
            "retry_count": 0,
            "created_at": current_time,
            "updated_at": current_time
        }
        await self.database.execute(query=query, values=values)
        
        # Insert tags if provided
        if "tags" in doc_data and doc_data["tags"]:
            tag_query = """
                INSERT INTO document_tags (document_id, tag)
                VALUES (:document_id, :tag)
            """
            tag_values = [{"document_id": doc_id, "tag": tag} for tag in doc_data["tags"]]
            await self.database.execute_many(query=tag_query, values=tag_values)
        
        # Link to another document if specified
        if "link_to_doc_id" in doc_data and doc_data["link_to_doc_id"]:
            link_query = """
                INSERT INTO document_links (source_doc_id, target_doc_id)
                VALUES (:source_doc_id, :target_doc_id)
            """
            link_values = {
                "source_doc_id": doc_id,
                "target_doc_id": doc_data["link_to_doc_id"]
            }
            await self.database.execute(query=link_query, values=link_values)
        
        # Fetch and return the created document
        return await self.get_by_id(doc_id)
    
    async def get_by_id(self, doc_id: str) -> Optional[Dict]:
        """
        Retrieve a document by its ID.
        
        Args:
            doc_id: Document ID
            
        Returns:
            Document as a dictionary or None if not found
        """
        # Fetch main document
        query = "SELECT * FROM documents WHERE id = :id"
        row = await self.database.fetch_one(query=query, values={"id": doc_id})
        
        if not row:
            return None
        
        # Convert row to dict
        doc = dict(row._mapping)
        
        # Fetch tags
        tag_query = "SELECT tag FROM document_tags WHERE document_id = :document_id"
        tag_rows = await self.database.fetch_all(query=tag_query, values={"document_id": doc_id})
        doc["tags"] = [row["tag"] for row in tag_rows]
        
        # Fetch linked document IDs
        link_query = """
            SELECT target_doc_id FROM document_links WHERE source_doc_id = :doc_id
            UNION
            SELECT source_doc_id FROM document_links WHERE target_doc_id = :doc_id
        """
        link_rows = await self.database.fetch_all(query=link_query, values={"doc_id": doc_id})
        doc["linked_document_ids"] = [row[0] for row in link_rows]
        
        return doc
    
    async def get_all(self, limit: int = 20, offset: int = 0) -> Tuple[List[Dict], int]:
        """
        Retrieve documents with pagination.
        
        Args:
            limit: Maximum number of documents to return
            offset: Number of documents to skip
            
        Returns:
            Tuple of (documents list, total count)
        """
        # Get total count
        count_query = "SELECT COUNT(*) as count FROM documents"
        count_result = await self.database.fetch_one(query=count_query)
        total = count_result["count"]
        
        # Get paginated documents
        docs_query = """
            SELECT * FROM documents 
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset
        """
        rows = await self.database.fetch_all(
            query=docs_query, 
            values={"limit": limit, "offset": offset}
        )
        
        if not rows:
            return [], total
        
        # Convert rows to documents and collect IDs
        documents = []
        doc_ids = []
        for row in rows:
            doc = dict(row._mapping)
            documents.append(doc)
            doc_ids.append(doc["id"])
        
        # Bulk fetch all tags for the retrieved documents
        if doc_ids:
            # Create parameterized query for IN clause
            placeholders = ', '.join([f':id{i}' for i in range(len(doc_ids))])
            tags_query = f"""
                SELECT document_id, tag 
                FROM document_tags 
                WHERE document_id IN ({placeholders})
            """
            tags_values = {f'id{i}': doc_id for i, doc_id in enumerate(doc_ids)}
            tag_rows = await self.database.fetch_all(query=tags_query, values=tags_values)
            
            # Map tags to documents
            tags_map = defaultdict(list)
            for row in tag_rows:
                tags_map[row["document_id"]].append(row["tag"])
            
            # Bulk fetch all links for the retrieved documents
            # Create separate placeholders for second condition
            placeholders2 = ', '.join([f':id2_{i}' for i in range(len(doc_ids))])
            links_query = f"""
                SELECT source_doc_id, target_doc_id 
                FROM document_links 
                WHERE source_doc_id IN ({placeholders}) 
                   OR target_doc_id IN ({placeholders2})
            """
            # Create values for both conditions
            links_values = {**tags_values}
            links_values.update({f'id2_{i}': doc_id for i, doc_id in enumerate(doc_ids)})
            link_rows = await self.database.fetch_all(query=links_query, values=links_values)
            
            # Map links to documents
            links_map = defaultdict(set)
            for row in link_rows:
                source_id = row["source_doc_id"]
                target_id = row["target_doc_id"]
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
    
    async def update_status(self, doc_id: str, status: str, 
                          processing_error: Optional[str] = None) -> None:
        """
        Update document processing status.
        
        Args:
            doc_id: Document ID
            status: New status
            processing_error: Error message if status is 'failed'
        """
        current_time = datetime.utcnow().isoformat()
        
        if processing_error:
            # Calculate next retry time with exponential backoff
            # Base delay: 60 seconds, exponential factor: 2
            retry_query = "SELECT retry_count FROM documents WHERE id = :id"
            result = await self.database.fetch_one(query=retry_query, values={"id": doc_id})
            retry_count = result["retry_count"] if result else 0
            
            # Exponential backoff: 1 min, 2 min, 4 min, 8 min, etc.
            # Cap at 10 minutes (600 seconds)
            delay_seconds = min(60 * (2 ** retry_count), 600)
            next_attempt = datetime.utcnow() + timedelta(seconds=delay_seconds)
            next_attempt_str = next_attempt.isoformat()
            
            query = """
                UPDATE documents 
                SET status = :status, processing_error = :error, last_error = :error,
                    updated_at = :updated_at, retry_count = retry_count + 1,
                    next_attempt_at = :next_attempt
                WHERE id = :id
            """
            values = {
                "status": status,
                "error": processing_error,
                "updated_at": current_time,
                "next_attempt": next_attempt_str,
                "id": doc_id
            }
        else:
            query = """
                UPDATE documents 
                SET status = :status, updated_at = :updated_at
                WHERE id = :id
            """
            values = {
                "status": status,
                "updated_at": current_time,
                "id": doc_id
            }
        
        await self.database.execute(query=query, values=values)
    
    async def get_failed_documents_for_retry(self, max_retries: int = 3) -> List[Dict]:
        """
        Get documents that failed but can be retried.
        
        Args:
            max_retries: Maximum number of retries allowed
            
        Returns:
            List of documents eligible for retry
        """
        query = """
            SELECT * FROM documents 
            WHERE status = 'failed' 
            AND retry_count < :max_retries
            AND (next_attempt_at IS NULL OR next_attempt_at <= :now)
            ORDER BY created_at ASC
            LIMIT 50
        """
        values = {
            "max_retries": max_retries,
            "now": datetime.utcnow().isoformat()
        }
        
        rows = await self.database.fetch_all(query=query, values=values)
        
        # Convert rows to dicts
        documents = []
        for row in rows:
            documents.append(dict(row._mapping))
        
        return documents