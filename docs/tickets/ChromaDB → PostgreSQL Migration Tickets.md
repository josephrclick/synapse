# 🎫 ChromaDB → PostgreSQL Migration Tickets

## Sprint 1: Foundation & Local Setup

### 📋 Ticket #1: PostgreSQL + pgvector Local Environment
**Priority**: 🔴 High  
**Estimated Time**: 2 hours

**Description**:  
Set up local PostgreSQL with pgvector extension for development. This replaces ChromaDB in our docker-compose setup and provides the foundation for all subsequent work.

**Technical Requirements**:
```yaml
# Add to docker-compose.yml
postgres:
  image: pgvector/pgvector:pg17
  container_name: synapse-postgres
  environment:
    POSTGRES_USER: synapse_user
    POSTGRES_PASSWORD: synapse_password
    POSTGRES_DB: synapse_db
    POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
  ports:
    - "5432:5432"
  volumes:
    - ./postgres_data:/var/lib/postgresql/data
    - ./init-scripts:/docker-entrypoint-initdb.d
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U synapse_user -d synapse_db"]
    interval: 10s
    timeout: 5s
    retries: 5
  networks:
    - synapse-network
```

**Acceptance Criteria**:
- [ ] PostgreSQL container starts with `make dev`
- [ ] pgvector extension is automatically enabled
- [ ] Health checks pass
- [ ] Can connect via `psql` from host
- [ ] ChromaDB removed from docker-compose

**Testing**:
```bash
# Verify setup
docker compose exec postgres psql -U synapse_user -d synapse_db -c "SELECT extversion FROM pg_extension WHERE extname='vector';"
# Should return version number
```

---

### 📋 Ticket #2: Database Schema & Migrations
**Priority**: 🔴 High  
**Estimated Time**: 1.5 hours  
**Dependencies**: Ticket #1

**Description**:  
Create database schema for documents with vector storage, implementing single-table design with type partitioning.

**Technical Requirements**:
```sql
-- Create init-scripts/01-schema.sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Main documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content storage (always keep original)
    original_content TEXT NOT NULL,
    processed_content TEXT NOT NULL,
    
    -- Metadata
    doc_type VARCHAR(50) NOT NULL CHECK (doc_type IN ('job_post', 'interview', 'personal', 'finance', 'note', 'other')),
    title TEXT NOT NULL,
    source_url TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Vector storage (1024d for mxbai-embed-large)
    embedding vector(1024),
    embedding_model VARCHAR(100) DEFAULT 'mxbai-embed-large',
    embedding_version INTEGER DEFAULT 1,
    
    -- Status tracking
    processing_status VARCHAR(20) DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    processing_error TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for hybrid search
CREATE INDEX idx_documents_embedding_hnsw ON documents 
USING hnsw (embedding vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);

CREATE INDEX idx_documents_fulltext ON documents 
USING GIN (to_tsvector('english', processed_content));

CREATE INDEX idx_documents_doc_type ON documents(doc_type);
CREATE INDEX idx_documents_status ON documents(processing_status);
CREATE INDEX idx_documents_created_at ON documents(created_at DESC);

-- Search function for hybrid search
CREATE OR REPLACE FUNCTION search_documents(
    query_text TEXT,
    query_embedding vector(1024),
    doc_types TEXT[] DEFAULT NULL,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    doc_type VARCHAR(50),
    similarity FLOAT,
    rank FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH vector_search AS (
        SELECT 
            d.id,
            d.title,
            d.processed_content,
            d.doc_type,
            1 - (d.embedding <=> query_embedding) AS similarity
        FROM documents d
        WHERE 
            d.embedding IS NOT NULL
            AND (doc_types IS NULL OR d.doc_type = ANY(doc_types))
        ORDER BY d.embedding <=> query_embedding
        LIMIT match_count * 2
    ),
    text_search AS (
        SELECT 
            d.id,
            ts_rank_cd(to_tsvector('english', d.processed_content), 
                      plainto_tsquery('english', query_text)) AS rank
        FROM documents d
        WHERE 
            to_tsvector('english', d.processed_content) @@ plainto_tsquery('english', query_text)
            AND (doc_types IS NULL OR d.doc_type = ANY(doc_types))
        LIMIT match_count * 2
    )
    SELECT DISTINCT ON (COALESCE(v.id, t.id))
        COALESCE(v.id, t.id) AS id,
        v.title,
        v.processed_content AS content,
        v.doc_type,
        v.similarity,
        t.rank
    FROM vector_search v
    FULL OUTER JOIN text_search t ON v.id = t.id
    ORDER BY COALESCE(v.id, t.id), 
             (COALESCE(v.similarity, 0) * 0.7 + COALESCE(t.rank, 0) * 0.3) DESC
    LIMIT match_count;
END;
$$;
```

**Acceptance Criteria**:
- [ ] Schema created successfully on container start
- [ ] All indexes created without errors
- [ ] Hybrid search function works with test data
- [ ] Can insert and retrieve documents

---

### 📋 Ticket #3: Update Python Dependencies
**Priority**: 🔴 High  
**Estimated Time**: 1 hour  
**Dependencies**: None

**Description**:  
Update backend dependencies to use pgvector-haystack instead of ChromaDB, ensuring compatibility with existing Haystack version.

**Technical Requirements**:
```python
# Update backend/requirements.in
# Remove:
# chroma-haystack==0.15.0
# chromadb<0.4.20

# Add:
pgvector-haystack==3.4.0
psycopg[binary]>=3.1,<4.0
asyncpg>=0.29.0  # For async operations

# Keep:
numpy<2.0.0  # Still required for compatibility
```

**Acceptance Criteria**:
- [ ] Run `pip-compile` to generate new requirements.txt
- [ ] All dependencies resolve without conflicts
- [ ] Backend starts without import errors
- [ ] Document any new environment variables needed

**Testing**:
```bash
cd backend
pip install -r requirements.txt
python -c "from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore; print('Import successful')"
```

---

## Sprint 2: Backend Migration

### 📋 Ticket #4: Update Configuration & Database Connection
**Priority**: 🔴 High  
**Estimated Time**: 1.5 hours  
**Dependencies**: Tickets #1, #2, #3

**Description**:  
Update configuration to support PostgreSQL connections and remove ChromaDB configuration.

**Technical Requirements**:
```python
# Update backend/config.py
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional
import os
from pathlib import Path

class Settings(BaseSettings):
    # ... existing settings ...
    
    # Remove ChromaDB settings:
    # chroma_host: str
    # chroma_port: int
    # chroma_collection_name: str
    
    # Add PostgreSQL settings:
    database_url: str = Field(
        default="postgresql://synapse_user:synapse_password@postgres:5432/synapse_db",
        description="PostgreSQL connection URL"
    )
    
    # For local development override
    database_url_local: Optional[str] = Field(
        default="postgresql://synapse_user:synapse_password@localhost:5432/synapse_db",
        description="Local PostgreSQL connection URL"
    )
    
    # Vector search settings
    vector_dimension: int = Field(default=1024, description="Embedding vector dimension")
    search_result_limit: int = Field(default=10, description="Default search result limit")
    hybrid_search_weight: float = Field(default=0.7, description="Weight for vector search vs text search")
    
    @property
    def get_database_url(self) -> str:
        """Return appropriate database URL based on environment"""
        if os.getenv("DOCKER_RUNNING", "false").lower() == "true":
            return self.database_url
        return self.database_url_local or self.database_url
```

**Acceptance Criteria**:
- [ ] ChromaDB configuration removed
- [ ] PostgreSQL connection works in Docker
- [ ] PostgreSQL connection works locally
- [ ] Environment variables documented

---

### 📋 Ticket #5: Implement PgvectorDocumentStore
**Priority**: 🔴 High  
**Estimated Time**: 2 hours  
**Dependencies**: Ticket #4

**Description**:  
Replace ChromaDB document store with PgvectorDocumentStore throughout the application.

**Technical Requirements**:
```python
# Create backend/document_store.py
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack.utils import Secret
from typing import Optional
import logging
from config import settings

logger = logging.getLogger(__name__)

class SynapseDocumentStore:
    """Wrapper for PgvectorDocumentStore with our configuration"""
    
    def __init__(self):
        self._store: Optional[PgvectorDocumentStore] = None
        
    def get_store(self) -> PgvectorDocumentStore:
        """Get or create document store instance"""
        if self._store is None:
            self._store = self._create_store()
        return self._store
    
    def _create_store(self) -> PgvectorDocumentStore:
        """Create PgvectorDocumentStore with our settings"""
        connection_string = Secret.from_token(settings.get_database_url)
        
        store = PgvectorDocumentStore(
            connection_string=connection_string,
            table_name="documents",
            embedding_dimension=settings.vector_dimension,
            vector_function="cosine_similarity",
            recreate_table=False,  # We handle schema separately
            search_strategy="hnsw",
            hnsw_recreate_index_if_exists=False,
            hnsw_index_name="idx_documents_embedding_hnsw",
            keyword_index_name="idx_documents_fulltext"
        )
        
        logger.info(f"Connected to PostgreSQL document store")
        logger.info(f"Document count: {store.count_documents()}")
        
        return store
    
    def reset(self):
        """Reset connection (useful for testing)"""
        self._store = None

# Singleton instance
document_store = SynapseDocumentStore()
```

**Acceptance Criteria**:
- [ ] Document store connects successfully
- [ ] Can write documents
- [ ] Can retrieve documents
- [ ] Count documents works
- [ ] No ChromaDB imports remain

---

### 📋 Ticket #6: Update RAG Pipelines
**Priority**: 🔴 High  
**Estimated Time**: 2.5 hours  
**Dependencies**: Ticket #5

**Description**:  
Update indexing and query pipelines to use PgvectorDocumentStore and implement hybrid search.

**Technical Requirements**:
```python
# Update backend/pipelines.py
from haystack import Pipeline, Document as HaystackDocument
from haystack.components.embedders import SentenceTransformersDocumentEmbedder, SentenceTransformersTextEmbedder
from haystack.components.preprocessors import DocumentCleaner, DocumentSplitter
from haystack.components.writers import DocumentWriter
from haystack_integrations.components.retrievers.pgvector import (
    PgvectorEmbeddingRetriever,
    PgvectorKeywordRetriever
)
from haystack.components.joiners import DocumentJoiner
from haystack.components.rankers import TransformersSimilarityRanker
from document_store import document_store
import logging

logger = logging.getLogger(__name__)

def get_indexing_pipeline() -> Pipeline:
    """Create document indexing pipeline"""
    pipeline = Pipeline()
    
    # Document processing
    pipeline.add_component("cleaner", DocumentCleaner(
        remove_empty_lines=True,
        remove_extra_whitespaces=True,
        remove_repeated_substrings=False
    ))
    
    pipeline.add_component("splitter", DocumentSplitter(
        split_by="sentence",
        split_length=10,
        split_overlap=2,
        split_threshold=5
    ))
    
    # Embedding
    pipeline.add_component("embedder", SentenceTransformersDocumentEmbedder(
        model="BAAI/bge-large-en-v1.5",  # Better than default
        device="cpu",
        normalize_embeddings=True
    ))
    
    # Writing
    pipeline.add_component("writer", DocumentWriter(
        document_store=document_store.get_store()
    ))
    
    # Connect components
    pipeline.connect("cleaner", "splitter")
    pipeline.connect("splitter", "embedder")
    pipeline.connect("embedder", "writer")
    
    return pipeline

def get_querying_pipeline() -> Pipeline:
    """Create hybrid search pipeline"""
    pipeline = Pipeline()
    
    # Query embedding
    pipeline.add_component("text_embedder", SentenceTransformersTextEmbedder(
        model="BAAI/bge-large-en-v1.5",
        device="cpu",
        normalize_embeddings=True
    ))
    
    # Retrievers
    pipeline.add_component("embedding_retriever", PgvectorEmbeddingRetriever(
        document_store=document_store.get_store(),
        top_k=20  # Get more for re-ranking
    ))
    
    pipeline.add_component("keyword_retriever", PgvectorKeywordRetriever(
        document_store=document_store.get_store(),
        top_k=20
    ))
    
    # Join results
    pipeline.add_component("joiner", DocumentJoiner(
        join_mode="reciprocal_rank_fusion"
    ))
    
    # Re-rank
    pipeline.add_component("ranker", TransformersSimilarityRanker(
        model="BAAI/bge-reranker-base",
        top_k=10
    ))
    
    # Connect for hybrid search
    pipeline.connect("text_embedder.embedding", "embedding_retriever.query_embedding")
    pipeline.connect("embedding_retriever", "joiner")
    pipeline.connect("keyword_retriever", "joiner")
    pipeline.connect("joiner", "ranker")
    
    return pipeline
```

**Acceptance Criteria**:
- [ ] Indexing pipeline processes documents
- [ ] Query pipeline returns relevant results
- [ ] Hybrid search works (vector + keyword)
- [ ] Re-ranking improves result quality

---

## Sprint 3: API Updates & Testing

### 📋 Ticket #7: Update API Endpoints
**Priority**: 🟡 Medium  
**Estimated Time**: 2 hours  
**Dependencies**: Tickets #5, #6

**Description**:  
Update all API endpoints to work with new document store, ensuring backward compatibility where possible.

**Technical Requirements**:
```python
# Update backend/main.py endpoints

@app.post("/api/documents", response_model=schemas.DocumentResponse)
async def create_document(
    doc_data: schemas.DocumentCreate,
    background_tasks: BackgroundTasks,
    api_key: str = Depends(get_api_key),
):
    """Create and process a document"""
    # Create document record in PostgreSQL
    doc_id = str(uuid.uuid4())
    
    async with get_db_connection() as conn:
        await conn.execute("""
            INSERT INTO documents (
                id, title, original_content, processed_content, 
                doc_type, source_url, metadata, processing_status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
        """, doc_id, doc_data.title, doc_data.content, doc_data.content,
             doc_data.doc_type or 'other', doc_data.source_url, 
             json.dumps(doc_data.metadata or {}))
    
    # Queue for processing
    background_tasks.add_task(process_document_task, doc_id)
    
    return schemas.DocumentResponse(
        id=doc_id,
        title=doc_data.title,
        status="pending",
        created_at=datetime.utcnow()
    )

@app.post("/api/chat", response_model=schemas.ChatResponse)
async def chat_query(
    query: schemas.ChatQuery,
    api_key: str = Depends(get_api_key),
):
    """Hybrid search with RAG"""
    # Get query pipeline
    pipeline = get_querying_pipeline()
    
    # Run hybrid search
    result = pipeline.run({
        "text_embedder": {"text": query.query},
        "keyword_retriever": {"query": query.query}
    })
    
    # Extract documents from ranker output
    documents = result.get("ranker", {}).get("documents", [])
    
    # Format response
    return schemas.ChatResponse(
        query=query.query,
        response=format_rag_response(query.query, documents),
        sources=[{
            "id": str(doc.id),
            "title": doc.meta.get("title", "Untitled"),
            "content_preview": doc.content[:200],
            "similarity_score": doc.score
        } for doc in documents[:5]]
    )
```

**Acceptance Criteria**:
- [ ] Document creation endpoint works
- [ ] Search endpoint returns results
- [ ] Background processing works
- [ ] Error handling is robust

---

### 📋 Ticket #8: Migration Script & Data Transfer
**Priority**: 🟡 Medium  
**Estimated Time**: 1.5 hours  
**Dependencies**: All previous tickets

**Description**:  
Create script to migrate any existing data from ChromaDB to PostgreSQL (if needed).

**Technical Requirements**:
```python
# Create scripts/migrate_to_postgres.py
import asyncio
import asyncpg
from haystack import Document
from typing import List
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def migrate_existing_data():
    """
    One-time migration script
    Note: Since we're in dev, this might just be a reset
    """
    logger.info("Starting migration to PostgreSQL...")
    
    # Since we're in development and don't have production data,
    # this can be simple test data insertion
    
    conn = await asyncpg.connect(
        "postgresql://synapse_user:synapse_password@localhost:5432/synapse_db"
    )
    
    try:
        # Insert test documents
        test_docs = [
            {
                "title": "Python Developer Interview",
                "content": "Discussed experience with FastAPI and async programming...",
                "doc_type": "interview",
                "metadata": {"company": "TechCorp", "position": "Senior Developer"}
            },
            {
                "title": "Machine Learning Job Post",
                "content": "Looking for ML engineer with experience in NLP and embeddings...",
                "doc_type": "job_post",
                "metadata": {"company": "AI Startup", "location": "Remote"}
            }
        ]
        
        for doc in test_docs:
            await conn.execute("""
                INSERT INTO documents (
                    title, original_content, processed_content,
                    doc_type, metadata, processing_status
                ) VALUES ($1, $2, $3, $4, $5, 'pending')
            """, doc["title"], doc["content"], doc["content"],
                 doc["doc_type"], json.dumps(doc["metadata"]))
        
        logger.info(f"Inserted {len(test_docs)} test documents")
        
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(migrate_existing_data())
```

**Acceptance Criteria**:
- [ ] Script runs without errors
- [ ] Test data inserted successfully
- [ ] Can be run multiple times safely
- [ ] Documents are searchable after insertion

---

### 📋 Ticket #9: Update Tests
**Priority**: 🟡 Medium  
**Estimated Time**: 2 hours  
**Dependencies**: All previous tickets

**Description**:  
Update test suite to work with PostgreSQL instead of ChromaDB.

**Technical Requirements**:
```python
# Update tests/test_vector_store.py
import pytest
import asyncio
from backend.document_store import document_store
from haystack import Document

@pytest.fixture
def reset_store():
    """Reset document store for tests"""
    document_store.reset()
    yield
    document_store.reset()

def test_document_store_connection(reset_store):
    """Test basic connection"""
    store = document_store.get_store()
    assert store is not None
    count = store.count_documents()
    assert isinstance(count, int)

def test_document_crud(reset_store):
    """Test document operations"""
    store = document_store.get_store()
    
    # Create
    doc = Document(
        content="Test content for vector search",
        meta={"title": "Test Doc", "doc_type": "test"}
    )
    store.write_documents([doc])
    
    # Read
    assert store.count_documents() > 0
    
    # Search (requires embedding)
    # This would need the full pipeline

def test_hybrid_search(reset_store):
    """Test hybrid search functionality"""
    # Would test both vector and keyword search
    pass
```

**Acceptance Criteria**:
- [ ] All existing tests updated
- [ ] New PostgreSQL-specific tests added
- [ ] Tests run in CI/CD pipeline
- [ ] No ChromaDB references in tests

---

## Sprint 4: Deployment & Documentation

### 📋 Ticket #10: Supabase Setup & Deployment
**Priority**: 🟡 Medium  
**Estimated Time**: 1.5 hours  
**Dependencies**: All previous tickets

**Description**:  
Configure Supabase project and deploy schema.

**Technical Requirements**:
```sql
-- Create supabase/migrations/001_initial_schema.sql
-- (Copy from local schema with Supabase-specific modifications)

-- Add RLS policies
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- For now, allow all operations (adjust based on auth strategy)
CREATE POLICY "Allow all operations" ON documents
    FOR ALL USING (true);
```

```bash
# Update .env.production
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
DATABASE_URL=postgresql://postgres:[password]@db.[project].supabase.co:5432/postgres
```

**Acceptance Criteria**:
- [ ] Supabase project created
- [ ] Schema deployed via migrations
- [ ] Connection from backend works
- [ ] Environment variables documented

---

### 📋 Ticket #11: Documentation & Cleanup
**Priority**: 🟢 Low  
**Estimated Time**: 1 hour  
**Dependencies**: All previous tickets

**Description**:  
Update all documentation and clean up ChromaDB references.

**Technical Requirements**:
- Update README.md
- Update CLAUDE.md with new architecture
- Remove ChromaDB from docker-compose
- Update Makefile commands
- Create migration guide

**Acceptance Criteria**:
- [ ] No ChromaDB references in code
- [ ] README reflects new setup
- [ ] Developer onboarding docs updated
- [ ] Deployment guide updated

---

## 🎯 Sprint Summary

**Sprint 1** (4-5 hours): Foundation
- Local PostgreSQL setup
- Schema creation
- Dependency updates

**Sprint 2** (6-7 hours): Core Migration  
- Configuration updates
- Document store implementation
- Pipeline updates

**Sprint 3** (5-6 hours): Integration
- API updates
- Migration tooling
- Test updates

**Sprint 4** (2-3 hours): Polish
- Supabase deployment
- Documentation
- Cleanup

**Total Estimate**: 17-21 hours (2-3 solid days of work)

Each ticket is designed to be completed independently once its dependencies are met, allowing for parallel work where possible. The migration can be completed incrementally with the system remaining functional throughout.