# PostgreSQL Migration Research Findings

## Executive Summary

This report outlines the findings from researching the migration of Synapse from ChromaDB to PostgreSQL with pgvector. The migration is well-planned in the ticket with 11 specific implementation tickets across 4 sprints. The total effort estimate is 17-21 hours.

## Current Architecture Analysis

### Database Structure
- **SQLite**: Used for document metadata and status tracking (async operations supported)
- **ChromaDB**: Used for vector storage and similarity search
- **Architecture**: Dual-database approach with SQLite for relational data and ChromaDB for vectors

### Key Components
1. **Document Model** (SQLite):
   - ID, type, title, content, source_url
   - Processing status tracking (pending/processing/completed/failed)
   - Retry logic with max_retries and next_attempt_at
   - Audit columns (created_at, updated_at)
   - Related tables: document_links, document_tags

2. **Vector Storage** (ChromaDB):
   - Embeddings stored in ChromaDB collection
   - Uses mxbai-embed-large model (1024 dimensions)
   - Haystack integration via chroma-haystack==0.15.0

3. **RAG Pipeline**:
   - Indexing: DocumentSplitter → OllamaDocumentEmbedder → ChromaDocumentStore
   - Querying: OllamaTextEmbedder → ChromaEmbeddingRetriever → ScoreFilter → DocumentLimiter → OllamaGenerator

## PostgreSQL Migration Strategy

### 1. Database Consolidation
The migration consolidates both SQLite and ChromaDB into a single PostgreSQL database with pgvector extension:

```sql
CREATE TABLE documents (
    id UUID PRIMARY KEY,
    original_content TEXT NOT NULL,
    processed_content TEXT NOT NULL,
    doc_type VARCHAR(50),
    title TEXT NOT NULL,
    source_url TEXT,
    metadata JSONB,
    embedding vector(1024),  -- pgvector column
    processing_status VARCHAR(20),
    -- timestamps
);
```

### 2. Technology Stack Updates
- **Remove**: chroma-haystack, chromadb, SQLite dependencies
- **Add**: 
  - pgvector-haystack==3.4.0 (official Haystack integration)
  - psycopg[binary]>=3.1,<4.0
  - asyncpg>=0.29.0 (for async operations)

### 3. Haystack Integration
The pgvector-haystack library provides:
- `PgvectorDocumentStore`: Replaces ChromaDocumentStore
- `PgvectorEmbeddingRetriever`: For vector similarity search
- `PgvectorKeywordRetriever`: For text-based search
- Built-in support for hybrid search (vector + keyword)

### 4. Key Implementation Considerations

#### A. Document Store Configuration
```python
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore

document_store = PgvectorDocumentStore(
    connection_string=Secret.from_token(database_url),
    table_name="documents",
    embedding_dimension=1024,
    vector_function="cosine_similarity",
    recreate_table=False,
    search_strategy="hnsw",  # High-performance indexing
    hnsw_recreate_index_if_exists=False
)
```

#### B. Hybrid Search Implementation
The ticket proposes a sophisticated hybrid search using:
- Vector search via pgvector's HNSW index
- Full-text search via PostgreSQL's GIN index
- Reciprocal rank fusion for result combination
- Transformer-based re-ranking (BAAI/bge-reranker-base)

#### C. Performance Optimizations
- HNSW index for fast approximate nearest neighbor search
- GIN index for full-text search
- Configurable search weights (default: 0.7 vector, 0.3 text)
- Connection pooling via asyncpg

## Risk Assessment & Mitigation

### 1. Data Migration
- **Risk**: Losing existing embeddings during migration
- **Mitigation**: Migration script provided in ticket #8
- **Note**: Since this is development, test data insertion is acceptable

### 2. Model Compatibility
- **Risk**: Embedding dimension mismatch
- **Mitigation**: Both systems use 1024-dimensional embeddings (mxbai-embed-large)

### 3. Performance
- **Risk**: PostgreSQL vector search slower than ChromaDB
- **Mitigation**: HNSW indexing provides O(log n) search complexity
- **Benefit**: Single database reduces network overhead

### 4. Dependency Conflicts
- **Risk**: Version conflicts with Haystack dependencies
- **Mitigation**: pgvector-haystack is officially maintained by Haystack team

## Implementation Approach

### Sprint 1 (Foundation - 4-5 hours)
1. Docker setup with pgvector/pgvector:pg17 image
2. Schema creation with proper indexes
3. Dependency updates

### Sprint 2 (Core Migration - 6-7 hours)
1. Configuration updates (remove ChromaDB, add PostgreSQL)
2. Document store wrapper implementation
3. Pipeline updates for indexing and querying

### Sprint 3 (Integration - 5-6 hours)
1. API endpoint updates
2. Migration tooling
3. Test suite updates

### Sprint 4 (Polish - 2-3 hours)
1. Supabase deployment configuration
2. Documentation updates
3. Final cleanup

## Best Practices from Research

### 1. Connection Management
```python
# Use environment-aware connection strings
@property
def get_database_url(self) -> str:
    if os.getenv("DOCKER_RUNNING", "false").lower() == "true":
        return self.database_url
    return self.database_url_local or self.database_url
```

### 2. Index Strategy
- Use HNSW for production (better query performance)
- Parameters: m=16, ef_construction=64 (balanced speed/accuracy)
- Always specify vector_ops for proper distance calculations

### 3. Error Handling
- Implement retry logic similar to existing ollama_retry decorator
- Health checks should verify both PostgreSQL and pgvector extension

### 4. Testing
- Use force_rollback in test mode for transaction isolation
- Create separate test database or schema

## Recommendations

1. **Follow the ticket plan**: The 11-ticket breakdown is comprehensive and well-structured
2. **Use official integrations**: pgvector-haystack is maintained by Haystack team
3. **Implement incrementally**: Each ticket can be completed independently
4. **Test thoroughly**: Especially the hybrid search functionality
5. **Monitor performance**: Compare query times before/after migration

## Next Steps

1. Get consensus on this analysis via zen tool
2. Prepare final implementation report with specific code examples
3. Begin Sprint 1 implementation starting with PostgreSQL container setup

## Resources
- [pgvector-haystack documentation](https://haystack.deepset.ai/integrations/pgvector-documentstore)
- [pgvector Python client](https://github.com/pgvector/pgvector-python)
- [Haystack PgvectorDocumentStore API](https://docs.haystack.deepset.ai/reference/integrations-pgvector)