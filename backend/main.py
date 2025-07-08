from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks, status
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import logging
import time
import asyncio

from . import database, schemas
from .dependencies import get_document_repository, get_repository
from .repositories import DocumentRepository
from .config import settings
from .logging_config import setup_logging
from .auth import get_api_key
from .pipelines import get_indexing_pipeline, get_querying_pipeline
from .middleware import RequestIDMiddleware
from .tasks import process_document_background, retry_failed_documents_task

# Import async database module when feature flag is enabled
if settings.use_async_db:
    from . import database_async

# Configure logging
setup_logging(settings.log_level)
logger = logging.getLogger(__name__)


async def run_retry_loop():
    """
    Background loop that periodically retries failed documents.
    """
    while True:
        await asyncio.sleep(900)  # Sleep for 15 minutes
        try:
            await retry_failed_documents_task()
        except Exception as e:
            logger.error(f"Error in retry loop: {e}", exc_info=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manage application lifespan events.
    Initialize database on startup.
    """
    # Startup
    logger.info(f"Starting {settings.app_name}...")
    logger.info(f"Async database mode: {'ENABLED' if settings.use_async_db else 'DISABLED'}")
    
    if settings.use_async_db:
        # Async database initialization
        await database_async.database.connect()
        await database_async.init_db()
        logger.info("Async database with connection pool initialized.")
    else:
        # Sync database initialization (existing)
        database.init_db()
    
    # Start the retry loop
    retry_task = asyncio.create_task(run_retry_loop())
    logger.info("Document retry loop started.")
    
    logger.info("Application startup complete.")
    
    yield
    
    # Shutdown
    logger.info("Application shutting down...")
    
    # Cancel retry loop
    retry_task.cancel()
    try:
        await retry_task
    except asyncio.CancelledError:
        logger.info("Retry loop cancelled.")
    
    if settings.use_async_db:
        await database_async.database.disconnect()
        logger.info("Async database connections closed.")


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    lifespan=lifespan
)

# Add middleware
app.add_middleware(RequestIDMiddleware)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # Next.js development server
        "http://localhost:3001",  # Alternative Next.js port
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
    ],
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers including X-API-KEY
)


@app.get("/health")
async def health_check():
    """
    Health check endpoint with comprehensive dependency status.
    Returns the health status of the application and its dependencies.
    """
    health_status = {
        "status": "healthy",
        "app_name": settings.app_name,
        "environment": settings.environment,
        "version": "1.0.0-mvp",
        "dependencies": {}
    }
    
    # Check SQLite
    try:
        if settings.use_async_db:
            # Async database check
            from . import database_async
            result = await database_async.database.fetch_one("SELECT COUNT(*) as count FROM documents")
            doc_count = result["count"] if result else 0
        else:
            # Sync database check
            conn = database.get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM documents")
            doc_count = cursor.fetchone()[0]
            conn.close()
            
        health_status["dependencies"]["sqlite"] = {
            "status": "healthy",
            "documents": doc_count,
            "path": settings.sqlite_db_path,
            "mode": "async" if settings.use_async_db else "sync"
        }
    except Exception as e:
        health_status["dependencies"]["sqlite"] = {
            "status": "unhealthy",
            "error": str(e)[:100]
        }
        health_status["status"] = "unhealthy"  # Critical dependency
    
    # Check Ollama
    try:
        import httpx
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.ollama_base_url}/api/tags",
                timeout=2.0
            )
            if response.status_code == 200:
                health_status["dependencies"]["ollama"] = {
                    "status": "healthy",
                    "url": settings.ollama_base_url,
                    "models": {
                        "generative": settings.generative_model,
                        "embedding": settings.embedding_model
                    }
                }
            else:
                health_status["dependencies"]["ollama"] = {
                    "status": "unhealthy",
                    "error": f"HTTP {response.status_code}"
                }
                health_status["status"] = "degraded"
    except Exception as e:
        health_status["dependencies"]["ollama"] = {
            "status": "unhealthy",
            "error": str(e)[:100]
        }
        health_status["status"] = "degraded"
    
    # Check ChromaDB
    try:
        import chromadb
        chroma_client = chromadb.HttpClient(
            host=settings.chroma_host,
            port=settings.chroma_port
        )
        # Try heartbeat as a health check
        chroma_client.heartbeat()
        health_status["dependencies"]["chromadb"] = {
            "status": "healthy",
            "host": f"{settings.chroma_host}:{settings.chroma_port}",
            "collection": settings.chroma_collection_name
        }
    except Exception as e:
        health_status["dependencies"]["chromadb"] = {
            "status": "unhealthy",
            "error": str(e)[:100],
            "note": "System will degrade gracefully"
        }
        health_status["status"] = "degraded"
    
    # Overall health assessment
    if health_status["status"] == "degraded":
        health_status["message"] = "Service operational with reduced functionality"
    elif health_status["status"] == "unhealthy":
        health_status["message"] = "Critical service failure"
    else:
        health_status["message"] = "All systems operational"
    
    return health_status


@app.post("/api/documents", 
         response_model=schemas.IngestionResponse,
         status_code=status.HTTP_202_ACCEPTED,
         dependencies=[Depends(get_api_key)])
async def create_document(
    doc_create: schemas.DocumentCreate,
    background_tasks: BackgroundTasks,
    repo = Depends(get_repository)
):
    """
    Create a new document and queue it for processing.
    Returns 202 Accepted with the document ID.
    """
    try:
        # Create document in database
        doc_dict = doc_create.model_dump()
        
        # Check if repository is async and await if needed
        if settings.use_async_db:
            created_doc = await repo.create(doc_dict)
        else:
            created_doc = repo.create(doc_dict)
        
        # Queue background processing
        background_tasks.add_task(process_document_background, created_doc["id"])
        
        return schemas.IngestionResponse(
            message="Document accepted for processing",
            doc_id=created_doc["id"],
            status=schemas.DocumentStatus.PENDING
        )
    except Exception as e:
        logger.error(f"Error creating document: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create document"
        )


@app.get("/api/documents",
         response_model=schemas.DocumentListResponse,
         dependencies=[Depends(get_api_key)])
async def get_documents(
    limit: int = 20,
    offset: int = 0,
    repo = Depends(get_repository)
):
    """
    Get paginated list of documents.
    """
    if limit > 100:
        limit = 100  # Cap maximum limit
        
    # Check if repository is async and await if needed
    if settings.use_async_db:
        documents, total = await repo.get_all(limit=limit, offset=offset)
    else:
        documents, total = repo.get_all(limit=limit, offset=offset)
    
    # Convert to response models
    doc_responses = []
    for doc in documents:
        doc_response = schemas.DocumentResponse(
            id=doc["id"],
            type=doc["type"],
            title=doc["title"],
            content=doc["content"],
            source_url=doc["source_url"],
            status=doc["status"],
            processing_error=doc["processing_error"],
            retry_count=doc["retry_count"],
            created_at=doc["created_at"],
            updated_at=doc["updated_at"],
            tags=doc["tags"],
            linked_document_ids=doc["linked_document_ids"]
        )
        doc_responses.append(doc_response)
    
    page = (offset // limit) + 1
    
    return schemas.DocumentListResponse(
        documents=doc_responses,
        total=total,
        page=page,
        page_size=limit
    )


@app.get("/api/documents/{doc_id}",
         response_model=schemas.DocumentResponse,
         dependencies=[Depends(get_api_key)])
async def get_document(
    doc_id: str,
    repo = Depends(get_repository)
):
    """
    Get a specific document by ID.
    """
    # Check if repository is async and await if needed
    if settings.use_async_db:
        doc = await repo.get_by_id(doc_id)
    else:
        doc = repo.get_by_id(doc_id)
    
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Document {doc_id} not found"
        )
    
    return schemas.DocumentResponse(
        id=doc["id"],
        type=doc["type"],
        title=doc["title"],
        content=doc["content"],
        source_url=doc["source_url"],
        status=doc["status"],
        processing_error=doc["processing_error"],
        retry_count=doc["retry_count"],
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
        tags=doc["tags"],
        linked_document_ids=doc["linked_document_ids"]
    )


@app.post("/api/chat",
         response_model=schemas.ChatResponse,
         dependencies=[Depends(get_api_key)])
async def chat(
    chat_request: schemas.ChatRequest
):
    """
    Process a chat query through the RAG pipeline.
    Returns an AI-generated answer based on the knowledge base.
    """
    start_time = time.time()
    
    try:
        # Get the querying pipeline
        querying_pipeline = get_querying_pipeline()
        
        logger.info(f"Processing chat query: '{chat_request.query[:100]}...'")
        
        # Run the pipeline with the user's query and context limit
        result = querying_pipeline.run({
            "query_embedder": {"text": chat_request.query},
            "doc_limiter": {"limit": chat_request.context_limit},
            "prompt_builder": {"query": chat_request.query}
        })
        
        # Extract the generated answer
        if not result or "generator" not in result:
            raise ValueError("Pipeline did not return a generator result")
        
        generator_result = result["generator"]
        if not generator_result or "replies" not in generator_result or not generator_result["replies"]:
            raise ValueError("No answer generated from the pipeline")
        
        answer = generator_result["replies"][0]
        
        # Extract source documents if available
        sources = []
        if "retriever" in result and "documents" in result["retriever"]:
            retrieved_docs = result["retriever"]["documents"]
            
            # Check if we have any documents
            if not retrieved_docs:
                logger.warning("No documents retrieved for query - possible empty knowledge base or no matches")
            
            for doc in retrieved_docs[:chat_request.context_limit]:
                source_info = {
                    "content": doc.content[:200] + "..." if len(doc.content) > 200 else doc.content,
                    "title": doc.meta.get("title", "Untitled"),
                    "doc_id": doc.meta.get("doc_id"),
                    "type": doc.meta.get("type")
                }
                sources.append(source_info)
        
        # Calculate query time
        query_time_ms = int((time.time() - start_time) * 1000)
        
        logger.info(f"Chat query processed successfully in {query_time_ms}ms")
        
        return schemas.ChatResponse(
            answer=answer,
            sources=sources if sources else None,
            query_time_ms=query_time_ms
        )
        
    except Exception as e:
        logger.error(f"Error processing chat query: {e}", exc_info=True)
        
        # Check if it's a ChromaDB connection issue
        if "ChromaDB" in str(e) or "connection" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Knowledge base is temporarily unavailable. Please try again later."
            )
        
        # Generic error response
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process chat query. Please try again."
        )