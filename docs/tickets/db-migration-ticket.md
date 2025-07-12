# 🚀 Synapse PostgreSQL Migration: Final Master Plan

## Executive Summary

**Goal**: Migrate from ChromaDB + SQLite to PostgreSQL with pgvector in a single sprint  
**Duration**: 10-12 hours total (1-2 coding sessions)  
**Approach**: Direct cutover with smart enhancements for long-term value  
**Key Innovation**: Smart chunking and auto-tagging for superior retrieval quality

## Architecture Overview

### Current State
- SQLite for metadata
- ChromaDB for vectors
- Dual database complexity

### Target State
- Single PostgreSQL database
- pgvector for embeddings
- JSONB for flexible metadata
- Smart content processing

## 🎫 Sprint Tickets

### Phase 1: Foundation (2-3 hours)

#### Ticket #1: PostgreSQL + pgvector Setup
**Priority**: 🔴 Critical  
**Estimated Time**: 1 hour

**Description**: Set up PostgreSQL with pgvector extension, replacing ChromaDB in docker-compose.

**Implementation**:
```yaml
# docker-compose.yml
postgres:
  image: pgvector/pgvector:pg17
  container_name: synapse-postgres
  environment:
    POSTGRES_USER: synapse_user
    POSTGRES_PASSWORD: synapse_password
    POSTGRES_DB: synapse_db
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
  command:
    - "postgres"
    - "-c"
    - "shared_preload_libraries=pg_stat_statements"
    - "-c"
    - "max_connections=200"
```

**Acceptance Criteria**:
- [ ] PostgreSQL starts with `make dev`
- [ ] pgvector extension enabled
- [ ] Can connect via psql
- [ ] Remove ChromaDB from docker-compose

---

#### Ticket #2: Database Schema with Smart Features
**Priority**: 🔴 Critical  
**Estimated Time**: 1 hour

**Description**: Create optimized schema with proper indexes and auto-tagging support.

**Implementation**:
```sql
-- init-scripts/01-schema.sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For fuzzy text matching

CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content storage
    original_content TEXT NOT NULL,
    processed_content TEXT NOT NULL,
    title TEXT NOT NULL,
    
    -- Smart categorization
    doc_type VARCHAR(50) NOT NULL,
    auto_tags TEXT[] DEFAULT '{}', -- Auto-generated tags
    user_tags TEXT[] DEFAULT '{}', -- User-defined tags
    
    -- Flexible metadata
    metadata JSONB DEFAULT '{}',
    
    -- Vector storage (1024d for mxbai-embed-large)
    embedding vector(1024),
    embedding_model VARCHAR(100) DEFAULT 'mxbai-embed-large',
    embedding_version INTEGER DEFAULT 1,
    
    -- Chunking metadata
    parent_doc_id UUID REFERENCES documents(id),
    chunk_index INTEGER,
    chunk_metadata JSONB DEFAULT '{}', -- Store chunk boundaries, semantic breaks
    
    -- Processing
    processing_status VARCHAR(20) DEFAULT 'pending',
    processing_error TEXT,
    
    -- Source
    source_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_embedding_hnsw ON documents 
USING hnsw (embedding vector_cosine_ops) 
WITH (m = 16, ef_construction = 64)
WHERE embedding IS NOT NULL;

CREATE INDEX idx_fulltext ON documents 
USING GIN (to_tsvector('english', processed_content));

CREATE INDEX idx_metadata ON documents USING GIN (metadata);
CREATE INDEX idx_auto_tags ON documents USING GIN (auto_tags);
CREATE INDEX idx_user_tags ON documents USING GIN (user_tags);
CREATE INDEX idx_doc_type ON documents(doc_type);
CREATE INDEX idx_parent_doc ON documents(parent_doc_id) WHERE parent_doc_id IS NOT NULL;

-- Hybrid search function
CREATE OR REPLACE FUNCTION search_documents(
    query_text TEXT,
    query_embedding vector(1024),
    search_tags TEXT[] DEFAULT NULL,
    doc_types TEXT[] DEFAULT NULL,
    limit_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    doc_type VARCHAR(50),
    tags TEXT[],
    similarity FLOAT,
    rank FLOAT
) AS $$
BEGIN
    RETURN QUERY
    WITH vector_search AS (
        SELECT 
            d.id,
            1 - (d.embedding <=> query_embedding) AS similarity
        FROM documents d
        WHERE 
            d.embedding IS NOT NULL
            AND (doc_types IS NULL OR d.doc_type = ANY(doc_types))
            AND (search_tags IS NULL OR d.auto_tags && search_tags OR d.user_tags && search_tags)
        ORDER BY d.embedding <=> query_embedding
        LIMIT limit_count * 2
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
            AND (search_tags IS NULL OR d.auto_tags && search_tags OR d.user_tags && search_tags)
        LIMIT limit_count * 2
    )
    SELECT DISTINCT ON (d.id)
        d.id,
        d.title,
        d.processed_content AS content,
        d.doc_type,
        d.auto_tags || d.user_tags AS tags,
        COALESCE(v.similarity, 0) AS similarity,
        COALESCE(t.rank, 0) AS rank
    FROM documents d
    LEFT JOIN vector_search v ON d.id = v.id
    LEFT JOIN text_search t ON d.id = t.id
    WHERE v.id IS NOT NULL OR t.id IS NOT NULL
    ORDER BY d.id, (COALESCE(v.similarity, 0) * 0.7 + COALESCE(t.rank, 0) * 0.3) DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;
```

**Acceptance Criteria**:
- [ ] Schema creates without errors
- [ ] All indexes created
- [ ] Hybrid search function works
- [ ] 1024 dimensions for embeddings (not 768)

---

#### Ticket #3: Update Dependencies
**Priority**: 🔴 Critical  
**Estimated Time**: 1 hour

**Description**: Update Python dependencies for PostgreSQL/pgvector.

**Implementation**:
```python
# backend/requirements.in - MUST USE THESE VERSIONS
haystack-ai==2.7.0  # Pin specific version
pgvector-haystack==3.4.0
ollama-haystack==1.1.0  # REQUIRED for Ollama integration
psycopg[binary,pool]>=3.1,<4.0
asyncpg>=0.29.0
numpy>=1.24.0,<2.0.0  # Prevent 2.0
nltk>=3.8.1
scikit-learn>=1.3.0,<2.0.0
transformers>=4.36.0,<5.0.0  # For reranker
```

**Test imports**:
```python
# Verify all imports work
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack_integrations.components.retrievers.pgvector import (
    PgvectorEmbeddingRetriever,
    PgvectorKeywordRetriever
)
```

---

#### Add New Ticket #3.5: Dependency Verification (5 minutes)

**Priority**: 🔴 Critical  
**After**: Ticket #3 **Time**: 5 minutes

bash

```
# Quick verification script
cd backend
pip-compile requirements.in
pip install -r requirements.txt

# Test critical imports
python -c "
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack_integrations.components.embedders.ollama import OllamaDocumentEmbedder
print('✅ Dependencies OK')
"
```

---

### Phase 2: Core Implementation (4-5 hours)

#### Ticket #4: Configuration & Connection Management
**Priority**: 🔴 Critical  
**Estimated Time**: 1 hour

**Description**: Update configuration with connection pooling.

**Implementation**:
```python
# backend/config.py
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional

class Settings(BaseSettings):
    # Remove all ChromaDB settings
    
    # PostgreSQL settings
    database_url: str = Field(
        default="postgresql://synapse_user:synapse_password@postgres:5432/synapse_db",
        description="PostgreSQL connection URL"
    )
    
    # Connection pool settings
    db_pool_min_size: int = Field(default=10, description="Minimum pool size")
    db_pool_max_size: int = Field(default=20, description="Maximum pool size")
    
    # Vector settings (FIXED to 1024)
    vector_dimension: int = Field(default=1024, description="mxbai-embed-large uses 1024")
    
    # Smart features
    enable_smart_chunking: bool = Field(default=True)
    enable_auto_tagging: bool = Field(default=True)
    chunk_size: int = Field(default=512, description="Target chunk size in tokens")
    chunk_overlap: int = Field(default=50, description="Overlap between chunks")

# backend/database.py
import asyncpg
from contextlib import asynccontextmanager

class DatabasePool:
    def __init__(self):
        self.pool = None
    
    async def initialize(self):
        self.pool = await asyncpg.create_pool(
            settings.database_url,
            min_size=settings.db_pool_min_size,
            max_size=settings.db_pool_max_size,
            command_timeout=60,
            server_settings={
                'jit': 'off',
                'application_name': 'synapse_backend'
            }
        )
    
    @asynccontextmanager
    async def acquire(self):
        async with self.pool.acquire() as conn:
            yield conn

db_pool = DatabasePool()
```

---

#### Ticket #5: Smart Document Processing
**Priority**: 🔴 Critical  
**Estimated Time**: 2 hours

**Description**: Implement smart chunking and auto-tagging.

**Implementation**:
```python
# backend/processors/smart_processor.py
import nltk
from typing import List, Dict, Tuple
from sklearn.feature_extraction.text import TfidfVectorizer
from collections import Counter
from haystack.dataclasses import Document  # Not 'from haystack import Document'
import re

class SmartDocumentProcessor:
    """Intelligent document processing with semantic chunking and auto-tagging"""
    
    def __init__(self):
        # Download required NLTK data
        nltk.download('punkt', quiet=True)
        nltk.download('stopwords', quiet=True)
        nltk.download('averaged_perceptron_tagger', quiet=True)
        
        self.stop_words = set(nltk.corpus.stopwords.words('english'))
    
    def process_document(self, content: str, doc_type: str) -> Dict:
        """Process document with smart chunking and tagging"""
        # Generate smart chunks
        chunks = self.smart_chunk(content, doc_type)
        
        # Extract auto-tags
        tags = self.extract_tags(content, doc_type)
        
        return {
            "chunks": chunks,
            "auto_tags": tags,
            "metadata": {
                "total_chunks": len(chunks),
                "avg_chunk_size": sum(len(c["content"]) for c in chunks) / len(chunks) if chunks else 0
            }
        }
    
    def smart_chunk(self, content: str, doc_type: str) -> List[Dict]:
        """Create semantically meaningful chunks"""
        chunks = []
        
        # Different strategies based on doc_type
        if doc_type == "interview":
            chunks = self._chunk_by_qa_pairs(content)
        elif doc_type == "job_post":
            chunks = self._chunk_by_sections(content)
        else:
            chunks = self._chunk_by_semantic_boundaries(content)
        
        return chunks
    
    def _chunk_by_semantic_boundaries(self, content: str) -> List[Dict]:
        """Chunk by paragraph boundaries and semantic coherence"""
        paragraphs = content.split('\n\n')
        chunks = []
        current_chunk = []
        current_size = 0
        
        for para in paragraphs:
            para_size = len(para.split())
            
            # Check if adding this paragraph would exceed chunk size
            if current_size + para_size > settings.chunk_size and current_chunk:
                chunks.append({
                    "content": '\n\n'.join(current_chunk),
                    "metadata": {
                        "chunk_type": "semantic",
                        "paragraph_count": len(current_chunk)
                    }
                })
                # Start new chunk with overlap
                overlap_text = ' '.join(current_chunk[-1].split()[-settings.chunk_overlap:])
                current_chunk = [overlap_text, para]
                current_size = len(overlap_text.split()) + para_size
            else:
                current_chunk.append(para)
                current_size += para_size
        
        # Add final chunk
        if current_chunk:
            chunks.append({
                "content": '\n\n'.join(current_chunk),
                "metadata": {
                    "chunk_type": "semantic",
                    "paragraph_count": len(current_chunk)
                }
            })
        
        return chunks
    
    def _chunk_by_qa_pairs(self, content: str) -> List[Dict]:
        """Special chunking for interview transcripts"""
        # Look for Q&A patterns
        qa_pattern = r'((?:Question|Q|Interviewer):.*?)(?=(?:Question|Q|Interviewer|Answer|A|Candidate):|$)'
        matches = re.findall(qa_pattern, content, re.DOTALL | re.IGNORECASE)
        
        chunks = []
        for i, match in enumerate(matches):
            chunks.append({
                "content": match.strip(),
                "metadata": {
                    "chunk_type": "qa_pair",
                    "question_index": i
                }
            })
        
        return chunks if chunks else self._chunk_by_semantic_boundaries(content)
    
    def _chunk_by_sections(self, content: str) -> List[Dict]:
        """Chunk job posts by natural sections"""
        section_headers = [
            "requirements", "qualifications", "responsibilities",
            "benefits", "about", "description", "skills"
        ]
        
        chunks = []
        lines = content.split('\n')
        current_section = []
        current_header = "general"
        
        for line in lines:
            # Check if line is a section header
            lower_line = line.lower().strip()
            is_header = any(header in lower_line for header in section_headers)
            
            if is_header and current_section:
                chunks.append({
                    "content": '\n'.join(current_section),
                    "metadata": {
                        "chunk_type": "section",
                        "section": current_header
                    }
                })
                current_section = [line]
                current_header = lower_line
            else:
                current_section.append(line)
        
        # Add final section
        if current_section:
            chunks.append({
                "content": '\n'.join(current_section),
                "metadata": {
                    "chunk_type": "section",
                    "section": current_header
                }
            })
        
        return chunks
    
    def extract_tags(self, content: str, doc_type: str) -> List[str]:
        """Extract meaningful tags from content"""
        tags = set()
        
        # Add doc_type as a tag
        tags.add(f"type:{doc_type}")
        
        # Extract named entities and key phrases
        sentences = nltk.sent_tokenize(content)
        words = nltk.word_tokenize(content.lower())
        
        # Remove stop words
        words = [w for w in words if w not in self.stop_words and w.isalnum()]
        
        # Get word frequency
        word_freq = Counter(words)
        
        # Extract top keywords (simple TF approach)
        top_keywords = [word for word, count in word_freq.most_common(10) if count > 2]
        tags.update(top_keywords)
        
        # Extract technology/skill mentions
        tech_patterns = [
            r'\b(python|javascript|java|c\+\+|react|vue|angular|node|django|fastapi)\b',
            r'\b(docker|kubernetes|aws|gcp|azure)\b',
            r'\b(machine learning|ai|ml|nlp|deep learning)\b',
            r'\b(postgresql|mysql|mongodb|redis)\b'
        ]
        
        for pattern in tech_patterns:
            matches = re.findall(pattern, content.lower())
            tags.update(matches)
        
        # Extract years of experience
        exp_pattern = r'(\d+)\+?\s*years?\s*(?:of\s*)?experience'
        exp_matches = re.findall(exp_pattern, content.lower())
        for years in exp_matches:
            tags.add(f"experience:{years}+years")
        
        # Limit tags
        return list(tags)[:20]
```

---

#### Ticket #6: Document Store Implementation
**Priority**: 🔴 Critical  
**Estimated Time**: 1.5 hours

**Description**: Create document store with smart features.

**Implementation**:
```python
# backend/document_store.py
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack.utils import Secret
from haystack.dataclasses import Document  # Not 'from haystack import Document'
from typing import List, Dict, Optional
import logging
from processors.smart_processor import SmartDocumentProcessor
from database import db_pool
import json

logger = logging.getLogger(__name__)

class SynapseDocumentStore:
    """Enhanced document store with smart features"""
    
    def __init__(self):
        self._store = None
        self.processor = SmartDocumentProcessor()
    
    def get_store(self) -> PgvectorDocumentStore:
        """Get or create document store"""
        if self._store is None:
            self._store = PgvectorDocumentStore(
                connection_string=Secret.from_token(settings.database_url),
                table_name="documents",
                embedding_dimension=1024,  # Fixed for mxbai-embed-large
                vector_function="cosine_similarity",
                recreate_table=False,
                search_strategy="hnsw"
            )
        return self._store
    
    async def write_document_with_processing(
        self, 
        content: str, 
        title: str,
        doc_type: str,
        metadata: Optional[Dict] = None
    ) -> List[str]:
        """Write document with smart chunking and tagging"""
        # Process document
        processed = self.processor.process_document(content, doc_type)
        
        # Store original document
        parent_doc = Document(
            content=content,
            meta={
                "title": title,
                "doc_type": doc_type,
                "is_parent": True,
                "auto_tags": processed["auto_tags"],
                "metadata": json.dumps(metadata or {}),
                "chunk_metadata": json.dumps(processed["metadata"])
            }
        )
        
        # Write parent
        self.get_store().write_documents([parent_doc])
        parent_id = parent_doc.id
        
        # Write chunks
        chunk_docs = []
        for i, chunk in enumerate(processed["chunks"]):
            chunk_doc = Document(
                content=chunk["content"],
                meta={
                    "title": f"{title} - Chunk {i+1}",
                    "doc_type": doc_type,
                    "parent_doc_id": parent_id,
                    "chunk_index": i,
                    "auto_tags": processed["auto_tags"],
                    "chunk_metadata": json.dumps(chunk["metadata"])
                }
            )
            chunk_docs.append(chunk_doc)
        
        if chunk_docs:
            self.get_store().write_documents(chunk_docs)
        
        # Update parent with chunk info in database
        async with db_pool.acquire() as conn:
            await conn.execute("""
                UPDATE documents 
                SET metadata = metadata || jsonb_build_object('total_chunks', $1)
                WHERE id = $2
            """, len(chunk_docs), parent_id)
        
        logger.info(f"Wrote document '{title}' with {len(chunk_docs)} chunks and {len(processed['auto_tags'])} tags")
        
        return [parent_id] + [doc.id for doc in chunk_docs]

# Singleton
document_store = SynapseDocumentStore()
```

---

#### Ticket #7: Ollama Connection Pool
**Priority**: 🟡 Medium  
**Estimated Time**: 0.5 hours

**Description**: Implement connection pooling for Ollama.

**Implementation**:
```python
# backend/ollama_pool.py
import asyncio
from typing import List, Optional
import httpx
from config import settings

class OllamaConnectionPool:
    """Connection pool for Ollama embeddings"""
    
    def __init__(self, max_connections: int = 5):
        self.semaphore = asyncio.Semaphore(max_connections)
        self.client = httpx.AsyncClient(
            base_url=settings.ollama_base_url,
            timeout=httpx.Timeout(30.0)
        )
    
    async def embed(self, text: str, model: str = None) -> List[float]:
        """Get embedding with connection limiting"""
        async with self.semaphore:
            response = await self.client.post(
                "/api/embeddings",
                json={
                    "model": model or settings.embedding_model,
                    "prompt": text
                }
            )
            response.raise_for_status()
            return response.json()["embedding"]
    
    async def embed_batch(self, texts: List[str], model: str = None) -> List[List[float]]:
        """Embed multiple texts efficiently"""
        tasks = [self.embed(text, model) for text in texts]
        return await asyncio.gather(*tasks)
    
    async def close(self):
        await self.client.aclose()

# Global instance
ollama_pool = OllamaConnectionPool()
```

---

### Phase 3: Pipeline & API Updates (3-4 hours)

#### Ticket #8: Update RAG Pipelines
**Priority**: 🔴 Critical  
**Estimated Time**: 2 hours

**Description**: Update pipelines with hybrid search and smart features.

**Implementation**:
```python
# backend/pipelines.py
from haystack import Pipeline
from haystack.dataclasses import Document
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack_integrations.components.retrievers.pgvector import (
    PgvectorEmbeddingRetriever,
    PgvectorKeywordRetriever
)
from haystack_integrations.components.embedders.ollama import (
    OllamaDocumentEmbedder,
    OllamaTextEmbedder
)
from haystack.components.joiners import DocumentJoiner
from haystack.components.rankers import TransformersSimilarityRanker
from haystack.components.builders import PromptBuilder
from haystack_integrations.components.generators.ollama import OllamaGenerator

logger = logging.getLogger(__name__)

class PooledOllamaTextEmbedder(OllamaTextEmbedder):
    """Ollama embedder using connection pool"""
    
    async def run(self, text: str):
        embedding = await ollama_pool.embed(text, self.model)
        return {"embedding": embedding}

def get_indexing_pipeline() -> Pipeline:
    """Indexing pipeline with proper embeddings"""
    pipeline = Pipeline()
    
    # Use Ollama for embeddings (1024 dimensions)
    pipeline.add_component("embedder", PooledOllamaDocumentEmbedder(
        model="mxbai-embed-large",
        url=settings.ollama_base_url
    ))
    
    pipeline.add_component("writer", DocumentWriter(
        document_store=document_store.get_store()
    ))
    
    pipeline.connect("embedder", "writer")
    
    return pipeline

def get_hybrid_search_pipeline() -> Pipeline:
    """Advanced hybrid search with re-ranking"""
    pipeline = Pipeline()
    
    # Query embedding
    pipeline.add_component("text_embedder", PooledOllamaTextEmbedder(
        model="mxbai-embed-large"
    ))
    
    # Dual retrievers
    pipeline.add_component("embedding_retriever", PgvectorEmbeddingRetriever(
        document_store=document_store.get_store(),
        top_k=30,  # Get more for re-ranking
        filters={"is_parent": {"$ne": True}}  # Only get chunks
    ))
    
    pipeline.add_component("keyword_retriever", PgvectorKeywordRetriever(
        document_store=document_store.get_store(),
        top_k=30,
        filters={"is_parent": {"$ne": True}}
    ))
    
    # Join with reciprocal rank fusion
    pipeline.add_component("joiner", DocumentJoiner(
        join_mode="reciprocal_rank_fusion",
        weights=[0.7, 0.3],  # Favor semantic search
        top_k=20
    ))
    
    # Re-rank for final results
    pipeline.add_component("ranker", TransformersSimilarityRanker(
        model="BAAI/bge-reranker-base",
        top_k=10,
        meta_fields_to_embed=["title", "auto_tags"]  # Include tags in ranking
    ))
    
    # RAG components
    pipeline.add_component("prompt_builder", PromptBuilder(
        template="""
        You are a helpful AI assistant. Use the following context to answer the question.
        
        Context:
        {% for doc in documents %}
        ---
        Title: {{ doc.meta.title }}
        Tags: {{ doc.meta.auto_tags | join(", ") }}
        Content: {{ doc.content }}
        ---
        {% endfor %}
        
        Question: {{ query }}
        
        Answer based on the context provided. If the context doesn't contain relevant information, say so.
        """
    ))
    
    pipeline.add_component("generator", OllamaGenerator(
        model=settings.generative_model,
        url=settings.ollama_base_url
    ))
    
    # Connect pipeline
    pipeline.connect("text_embedder.embedding", "embedding_retriever.query_embedding")
    pipeline.connect("embedding_retriever", "joiner")
    pipeline.connect("keyword_retriever", "joiner")
    pipeline.connect("joiner", "ranker")
    pipeline.connect("ranker", "prompt_builder.documents")
    pipeline.connect("prompt_builder", "generator")
    
    return pipeline
```

---

#### Ticket #9: API Endpoint Updates
**Priority**: 🔴 Critical  
**Estimated Time**: 1.5 hours

**Description**: Update API to use new document store and features.

**Implementation**:
```python
# backend/main.py updates
from document_store import document_store
from pipelines import get_hybrid_search_pipeline

@app.post("/api/documents", response_model=schemas.DocumentResponse)
async def create_document(
    doc_data: schemas.DocumentCreate,
    background_tasks: BackgroundTasks,
    api_key: str = Depends(get_api_key),
):
    """Create document with smart processing"""
    try:
        # Process and store document
        doc_ids = await document_store.write_document_with_processing(
            content=doc_data.content,
            title=doc_data.title,
            doc_type=doc_data.doc_type or "general",
            metadata=doc_data.metadata
        )
        
        return schemas.DocumentResponse(
            id=doc_ids[0],  # Parent doc ID
            title=doc_data.title,
            status="completed",
            metadata={
                "total_chunks": len(doc_ids) - 1,
                "doc_type": doc_data.doc_type
            }
        )
    except Exception as e:
        logger.error(f"Document creation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/search", response_model=schemas.SearchResponse)
async def hybrid_search(
    query: schemas.SearchQuery,
    api_key: str = Depends(get_api_key),
):
    """Hybrid search with smart features"""
    pipeline = get_hybrid_search_pipeline()
    
    # Add filters for tags if provided
    filters = {}
    if query.tags:
        filters["auto_tags"] = {"$in": query.tags}
    if query.doc_types:
        filters["doc_type"] = {"$in": query.doc_types}
    
    # Run search
    result = await pipeline.run_async({
        "text_embedder": {"text": query.query},
        "embedding_retriever": {"filters": filters},
        "keyword_retriever": {"query": query.query, "filters": filters},
        "prompt_builder": {"query": query.query}
    })
    
    # Extract results
    documents = result.get("ranker", {}).get("documents", [])
    generated_answer = result.get("generator", {}).get("replies", [""])[0]
    
    return schemas.SearchResponse(
        query=query.query,
        answer=generated_answer,
        documents=[{
            "id": doc.id,
            "title": doc.meta.get("title", ""),
            "content": doc.content[:200] + "...",
            "score": doc.score,
            "tags": doc.meta.get("auto_tags", [])
        } for doc in documents]
    )

@app.get("/api/tags", response_model=List[str])
async def get_popular_tags(
    limit: int = 20,
    api_key: str = Depends(get_api_key),
):
    """Get most popular auto-generated tags"""
    async with db_pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT unnest(auto_tags) as tag, COUNT(*) as count
            FROM documents
            GROUP BY tag
            ORDER BY count DESC
            LIMIT $1
        """, limit)
        
        return [row["tag"] for row in rows]
```

---

### Phase 4: Migration & Cleanup (1-2 hours)

#### Ticket #10: Simple Migration Script
**Priority**: 🟡 Medium  
**Estimated Time**: 0.5 hours

**Description**: Create migration script (or just start fresh).

**Implementation**:
```python
# scripts/fresh_start.py
"""
Since we're in development, this just ensures clean setup
"""
import asyncio
from database import db_pool
from document_store import document_store

async def fresh_start():
    """Initialize with test data"""
    await db_pool.initialize()
    
    # Add some test documents
    test_docs = [
        {
            "title": "Senior Python Developer Position",
            "content": """We are looking for a Senior Python Developer with 5+ years experience.
            Requirements include expertise in FastAPI, PostgreSQL, and Docker.
            Experience with machine learning is a plus.""",
            "doc_type": "job_post"
        },
        {
            "title": "ML Engineer Interview Notes",
            "content": """Candidate showed strong understanding of transformer models.
            Discussed experience with pgvector and embedding databases.
            Good cultural fit, recommended for next round.""",
            "doc_type": "interview"
        }
    ]
    
    for doc in test_docs:
        await document_store.write_document_with_processing(**doc)
    
    print("✅ Fresh start complete with test data")

if __name__ == "__main__":
    asyncio.run(fresh_start())
```

---

#### Ticket #11: Update Tests & Documentation
**Priority**: 🟡 Medium  
**Estimated Time**: 1 hour

**Description**: Update tests and remove ChromaDB references.

**Implementation**:
```python
# tests/test_smart_features.py
import pytest
from processors.smart_processor import SmartDocumentProcessor

def test_smart_chunking():
    processor = SmartDocumentProcessor()
    
    content = """This is the first paragraph about Python programming.
    
    This is the second paragraph about machine learning.
    
    This is the third paragraph about deployment."""
    
    chunks = processor.smart_chunk(content, "general")
    assert len(chunks) > 0
    assert all("content" in chunk for chunk in chunks)

def test_auto_tagging():
    processor = SmartDocumentProcessor()
    
    content = "Looking for Python developer with 5+ years experience in FastAPI and Docker"
    tags = processor.extract_tags(content, "job_post")
    
    assert "python" in tags
    assert "fastapi" in tags
    assert "docker" in tags
    assert "experience:5+years" in tags
```

**Documentation Updates**:
- Remove all ChromaDB references from README.md
- Update CLAUDE.md with new architecture
- Create SMART_FEATURES.md documenting chunking and tagging

---

## 🎯 Implementation Timeline

**Day 1 (4-5 hours)**:
- Morning: Tickets #1-3 (Foundation)
- Afternoon: Tickets #4-6 (Core Implementation)

**Day 2 (4-5 hours)**:
- Morning: Tickets #7-9 (Pipeline & API)
- Afternoon: Tickets #10-11 (Migration & Testing)

## 🚀 Quick Start Commands

```bash
# Remove ChromaDB and start fresh
docker-compose down -v
rm -rf chroma_data/

# Start PostgreSQL
make db-start

# Update dependencies
cd backend && pip-compile && pip install -r requirements.txt

# Run fresh start
python scripts/fresh_start.py

# Test the system
curl -X POST http://localhost:8101/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "Python developer with FastAPI experience"}'
```

## ✅ Success Criteria

1. **All tests pass** with PostgreSQL
2. **Smart chunking** creates meaningful segments
3. **Auto-tagging** extracts relevant keywords
4. **Hybrid search** returns relevant results
5. **No ChromaDB** references remain
6. **Performance baseline** established

## 🎉 Benefits Achieved

- **Unified Database**: Single source of truth
- **Smart Features**: Better retrieval through intelligent processing
- **Future-Proof**: JSONB metadata allows unlimited extensibility
- **Performance**: HNSW + GIN indexes for fast search
- **Developer Experience**: Simpler setup and maintenance

This plan delivers a solid foundation for Synapse while keeping implementation simple and focused on high-value features.