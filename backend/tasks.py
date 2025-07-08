"""
Background tasks module for Capture-v3.

This module contains background processing logic that runs asynchronously
after API endpoints return responses to clients. It's designed to decouple
the web layer from task execution logic, making it easier to migrate to
dedicated task queues (like Celery or Dramatiq) in the future.
"""
import logging
from haystack import Document as HaystackDocument

import database
from pipelines import get_indexing_pipeline
from repositories import DocumentRepository
from config import settings

# Import async modules when feature flag is enabled
if settings.use_async_db:
    import database_async
    from repositories_async import DocumentRepositoryAsync

# Configure logger for this module
logger = logging.getLogger(__name__)


# Background task for document processing
async def process_document_background(doc_id: str):
    """
    Process document in the background using Haystack RAG pipeline.
    This function runs asynchronously after returning 202 to the client.
    Supports both sync and async database operations based on feature flag.
    """
    logger.info(f"Starting background processing for document {doc_id}")
    
    # Create database repository based on feature flag
    conn = None
    repo = None
    
    try:
        if settings.use_async_db:
            # Async database operations
            repo = DocumentRepositoryAsync(database_async.database)
            
            # Update status to processing
            await repo.update_status(doc_id, "processing")
            logger.info(f"Updated document {doc_id} status to processing")
            
            # Fetch document from database
            doc_data = await repo.get_by_id(doc_id)
        else:
            # Sync database operations (existing logic)
            conn = database.get_db_connection()
            repo = DocumentRepository(conn)
            
            # Update status to processing
            repo.update_status(doc_id, "processing")
            logger.info(f"Updated document {doc_id} status to processing")
            
            # Fetch document from database
            doc_data = repo.get_by_id(doc_id)
            
        if not doc_data:
            raise ValueError(f"Document {doc_id} not found in database")
        
        # Convert to Haystack Document format
        haystack_doc = HaystackDocument(
            content=doc_data["content"],
            meta={
                "doc_id": doc_data["id"],
                "title": doc_data["title"],
                "type": doc_data["type"],
                "source_url": doc_data["source_url"],
                "tags": doc_data["tags"] if doc_data["tags"] else [],
                "created_at": doc_data["created_at"]
            }
        )
        
        # Get the indexing pipeline
        indexing_pipeline = get_indexing_pipeline()
        
        # Run the pipeline
        logger.info(f"Running indexing pipeline for document {doc_id}")
        result = indexing_pipeline.run({"documents": [haystack_doc]})
        
        # Log pipeline result
        if result and "writer" in result:
            written_docs = result["writer"].get("documents_written", 0)
            logger.info(f"Successfully indexed {written_docs} chunks for document {doc_id}")
        
        # Update status to completed
        if settings.use_async_db:
            await repo.update_status(doc_id, "completed")
        else:
            repo.update_status(doc_id, "completed")
        logger.info(f"Completed processing document {doc_id}")
        
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Error processing document {doc_id}: {error_msg}", exc_info=True)
        
        # Update status to failed with error message
        if repo:
            try:
                # Limit error message length to prevent database issues
                truncated_error = error_msg[:500] if len(error_msg) > 500 else error_msg
                if settings.use_async_db:
                    await repo.update_status(doc_id, "failed", truncated_error)
                else:
                    repo.update_status(doc_id, "failed", truncated_error)
            except Exception as update_error:
                logger.error(f"Failed to update document status: {update_error}")
    
    finally:
        # Ensure database connection is closed
        if conn:
            conn.close()


async def retry_failed_documents_task():
    """
    Background task that retries failed documents.
    This function checks for documents that failed processing but haven't 
    exceeded their retry limit and re-queues them for processing.
    """
    logger.info("Starting retry cycle for failed documents")
    
    try:
        if settings.use_async_db:
            # Async database operations
            repo = DocumentRepositoryAsync(database_async.database)
            failed_docs = await repo.get_failed_documents_for_retry()
        else:
            # Sync database operations
            conn = database.get_db_connection()
            try:
                repo = DocumentRepository(conn)
                failed_docs = repo.get_failed_documents_for_retry()
            finally:
                conn.close()
        
        if not failed_docs:
            logger.info("No failed documents found for retry")
            return
        
        logger.info(f"Found {len(failed_docs)} documents to retry")
        
        # Re-queue each document for processing
        for doc in failed_docs:
            doc_id = doc["id"]
            retry_count = doc.get("retry_count", 0)
            logger.info(f"Re-queuing document {doc_id} for retry (attempt #{retry_count + 1})")
            
            # Reset status to pending to trigger processing
            if settings.use_async_db:
                await repo.update_status(doc_id, "pending")
            else:
                conn = database.get_db_connection()
                try:
                    repo = DocumentRepository(conn)
                    repo.update_status(doc_id, "pending")
                finally:
                    conn.close()
            
            # Queue the document for processing
            # Note: In a real async environment, this would be better handled
            # with a proper task queue, but for now we'll process directly
            await process_document_background(doc_id)
        
        logger.info(f"Completed retry cycle, re-queued {len(failed_docs)} documents")
        
    except Exception as e:
        logger.error(f"Error in retry task: {e}", exc_info=True)