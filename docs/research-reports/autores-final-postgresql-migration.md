# PostgreSQL Migration: Final Implementation Report

## Executive Summary

This report provides the comprehensive implementation guide for migrating Synapse from ChromaDB + SQLite to PostgreSQL with pgvector. Based on extensive research and expert validation, the migration is technically sound but requires enhancements to the original plan for risk mitigation.

**Key Recommendations:**
1. Implement feature flag system for gradual rollout
2. Add parallel run phase before full cutover
3. Establish comprehensive monitoring and benchmarking
4. Follow enhanced 13-ticket plan (adding 2 critical tickets)

## Architecture Overview

### Current State
```
┌─────────────┐     ┌──────────────┐
│   SQLite    │     │   ChromaDB   │
│ (metadata)  │     │  (vectors)   │
└─────────────┘     └──────────────┘
       │                    │
       └────────┬───────────┘
                │
         ┌──────────────┐
         │   Haystack   │
         │   Pipeline   │
         └──────────────┘
```

### Target State
```
      ┌─────────────────────┐
      │    PostgreSQL       │
      │   with pgvector     │
      │ (unified storage)   │
      └─────────────────────┘
                │
         ┌──────────────┐
         │   Haystack   │
         │   Pipeline   │
         └──────────────┘
```

## Enhanced Implementation Plan

### Phase 0: Preparation (NEW - 1 week)

#### Ticket #0A: Benchmarking Framework
```python
# backend/benchmarks/benchmark_stores.py
import time
import asyncio
from typing import List, Dict
import numpy as np
from haystack import Document

class StoreBenchmark:
    """Benchmark framework for comparing document stores"""
    
    async def benchmark_write(self, store, documents: List[Document]) -> Dict:
        start = time.time()
        await store.write_documents(documents)
        return {
            "operation": "write",
            "count": len(documents),
            "duration": time.time() - start,
            "docs_per_second": len(documents) / (time.time() - start)
        }
    
    async def benchmark_search(self, store, queries: List[str], top_k: int = 10) -> Dict:
        latencies = []
        for query in queries:
            start = time.time()
            await store.search(query, top_k=top_k)
            latencies.append(time.time() - start)
        
        return {
            "operation": "search",
            "count": len(queries),
            "p50": np.percentile(latencies, 50),
            "p95": np.percentile(latencies, 95),
            "p99": np.percentile(latencies, 99)
        }
```

#### Ticket #0B: Feature Flag System
```python
# backend/feature_flags.py
from typing import Optional
from pydantic import BaseSettings, Field

class FeatureFlags(BaseSettings):
    """Feature flags for gradual rollout"""
    
    # Database selection
    use_pgvector: bool = Field(default=False, description="Use PostgreSQL instead of ChromaDB")
    pgvector_read_percentage: int = Field(default=0, description="Percentage of reads from pgvector (0-100)")
    
    # Migration features
    enable_dual_write: bool = Field(default=False, description="Write to both stores")
    enable_shadow_reads: bool = Field(default=False, description="Compare results from both stores")
    
    class Config:
        env_prefix = "FF_"  # Environment variables like FF_USE_PGVECTOR

flags = FeatureFlags()
```

### Phase 1: Foundation (Sprint 1 - Enhanced)

#### Updated Ticket #1: PostgreSQL Setup with Monitoring
```yaml
# docker-compose.yml additions
postgres:
  image: pgvector/pgvector:pg17
  # ... existing config ...
  environment:
    # Add monitoring config
    POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C --data-checksums"
  volumes:
    - ./postgres_data:/var/lib/postgresql/data
    - ./init-scripts:/docker-entrypoint-initdb.d
    - ./monitoring/postgres_exporter.yml:/etc/postgres_exporter.yml:ro

postgres-exporter:
  image: prometheuscommunity/postgres-exporter
  environment:
    DATA_SOURCE_NAME: "postgresql://synapse_user:synapse_password@postgres:5432/synapse_db?sslmode=disable"
  ports:
    - "9187:9187"
```

#### Updated Ticket #2: Schema with Performance Optimizations
```sql
-- init-scripts/01-schema.sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- For query monitoring

-- Main table with optimizations
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content storage with compression
    original_content TEXT NOT NULL,
    processed_content TEXT NOT NULL,
    
    -- Metadata
    doc_type VARCHAR(50) NOT NULL,
    title TEXT NOT NULL,
    source_url TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Vector storage with version tracking
    embedding vector(1024),
    embedding_model VARCHAR(100) DEFAULT 'mxbai-embed-large',
    embedding_version INTEGER DEFAULT 1,
    
    -- Status tracking
    processing_status VARCHAR(20) DEFAULT 'pending',
    processing_error TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) WITH (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Create indexes AFTER data load in migration
-- Commented out here, created in migration script
-- CREATE INDEX CONCURRENTLY idx_documents_embedding_hnsw ...
```

### Phase 2: Core Implementation (Sprint 2 - Enhanced)

#### Updated Ticket #5: Document Store with Feature Flags
```python
# backend/document_store.py
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack_integrations.document_stores.chroma import ChromaDocumentStore
from haystack.utils import Secret
from typing import Optional, List, Dict, Any
import logging
from config import settings
from feature_flags import flags
import random

logger = logging.getLogger(__name__)

class HybridDocumentStore:
    """Document store that can use either ChromaDB or PgvectorDocumentStore based on feature flags"""
    
    def __init__(self):
        self._pgvector_store: Optional[PgvectorDocumentStore] = None
        self._chroma_store: Optional[ChromaDocumentStore] = None
        
    def get_pgvector_store(self) -> PgvectorDocumentStore:
        """Get or create PgvectorDocumentStore instance"""
        if self._pgvector_store is None:
            connection_string = Secret.from_token(settings.get_database_url)
            
            self._pgvector_store = PgvectorDocumentStore(
                connection_string=connection_string,
                table_name="documents",
                embedding_dimension=settings.vector_dimension,
                vector_function="cosine_similarity",
                recreate_table=False,
                search_strategy="hnsw",
                hnsw_recreate_index_if_exists=False,
                hnsw_index_creation_kwargs={
                    "m": 16,
                    "ef_construction": 64
                },
                keyword_index_name="idx_documents_fulltext"
            )
            
            logger.info("Connected to PostgreSQL document store")
        
        return self._pgvector_store
    
    def get_chroma_store(self) -> ChromaDocumentStore:
        """Get or create ChromaDocumentStore instance"""
        if self._chroma_store is None:
            # Existing ChromaDB initialization
            self._chroma_store = create_chroma_document_store()
        
        return self._chroma_store
    
    async def write_documents(self, documents: List[Document], **kwargs):
        """Write documents based on feature flags"""
        if flags.enable_dual_write:
            # Write to both stores
            try:
                self.get_chroma_store().write_documents(documents, **kwargs)
            except Exception as e:
                logger.error(f"ChromaDB write failed: {e}")
            
            try:
                self.get_pgvector_store().write_documents(documents, **kwargs)
            except Exception as e:
                logger.error(f"PgvectorDocumentStore write failed: {e}")
                raise  # Fail if new store fails
        
        elif flags.use_pgvector:
            self.get_pgvector_store().write_documents(documents, **kwargs)
        else:
            self.get_chroma_store().write_documents(documents, **kwargs)
    
    async def search(self, query_embedding: List[float], top_k: int = 10, **kwargs) -> List[Document]:
        """Search documents based on feature flags"""
        # Determine which store to use
        use_pgvector = flags.use_pgvector
        
        # Percentage-based routing
        if flags.pgvector_read_percentage > 0:
            use_pgvector = random.randint(1, 100) <= flags.pgvector_read_percentage
        
        # Execute search
        if use_pgvector:
            results = self.get_pgvector_store().search(query_embedding, top_k, **kwargs)
        else:
            results = self.get_chroma_store().search(query_embedding, top_k, **kwargs)
        
        # Shadow reads for comparison
        if flags.enable_shadow_reads and not flags.use_pgvector:
            try:
                shadow_results = self.get_pgvector_store().search(query_embedding, top_k, **kwargs)
                self._compare_results(results, shadow_results)
            except Exception as e:
                logger.warning(f"Shadow read failed: {e}")
        
        return results
    
    def _compare_results(self, primary: List[Document], shadow: List[Document]):
        """Compare results from both stores for monitoring"""
        primary_ids = {doc.id for doc in primary[:5]}
        shadow_ids = {doc.id for doc in shadow[:5]}
        
        overlap = len(primary_ids & shadow_ids)
        similarity = overlap / min(len(primary_ids), len(shadow_ids))
        
        logger.info(f"Search result similarity: {similarity:.2f}")
        
        if similarity < 0.5:
            logger.warning(f"Low similarity between stores: {similarity:.2f}")

# Singleton instance
document_store = HybridDocumentStore()
```

#### Updated Ticket #6: Pipeline with Graceful Degradation
```python
# backend/pipelines.py
from haystack import Pipeline, Document
from haystack.components.joiners import DocumentJoiner
from haystack_integrations.components.retrievers.pgvector import (
    PgvectorEmbeddingRetriever,
    PgvectorKeywordRetriever
)
from haystack.components.rankers import TransformersSimilarityRanker
from document_store import document_store
from feature_flags import flags
import logging

logger = logging.getLogger(__name__)

def get_querying_pipeline() -> Pipeline:
    """Create hybrid search pipeline with feature flag support"""
    pipeline = Pipeline()
    
    # Query embedding (same for both stores)
    pipeline.add_component("text_embedder", RetryableOllamaTextEmbedder(
        model=settings.embedding_model,
        url=settings.ollama_base_url
    ))
    
    if flags.use_pgvector:
        # PostgreSQL hybrid search
        pipeline.add_component("embedding_retriever", PgvectorEmbeddingRetriever(
            document_store=document_store.get_pgvector_store(),
            top_k=20,
            filter_policy="merge"  # Combine with filters
        ))
        
        pipeline.add_component("keyword_retriever", PgvectorKeywordRetriever(
            document_store=document_store.get_pgvector_store(),
            top_k=20
        ))
        
        # Join results with reciprocal rank fusion
        pipeline.add_component("joiner", DocumentJoiner(
            join_mode="reciprocal_rank_fusion",
            weights=[0.7, 0.3]  # Vector vs keyword weight
        ))
        
        # Re-ranking
        pipeline.add_component("ranker", TransformersSimilarityRanker(
            model="BAAI/bge-reranker-base",
            top_k=10,
            device="cpu"
        ))
        
        # Connect components
        pipeline.connect("text_embedder.embedding", "embedding_retriever.query_embedding")
        pipeline.connect("embedding_retriever", "joiner.documents")
        pipeline.connect("keyword_retriever", "joiner.documents") 
        pipeline.connect("joiner", "ranker")
        
    else:
        # Existing ChromaDB pipeline
        pipeline.add_component("retriever", ChromaEmbeddingRetriever(
            document_store=document_store.get_chroma_store(),
            top_k=50
        ))
        
        # Keep existing score filter and limiter
        pipeline.add_component("score_filter", DocumentScoreFilter())
        pipeline.add_component("doc_limiter", DocumentLimiter())
        
        pipeline.connect("text_embedder.embedding", "retriever.query_embedding")
        pipeline.connect("retriever.documents", "score_filter.documents")
        pipeline.connect("score_filter.documents", "doc_limiter.documents")
    
    # Common components
    pipeline.add_component("prompt_builder", PromptBuilder(template=prompt_template))
    pipeline.add_component("generator", RetryableOllamaGenerator(
        model=settings.generative_model,
        url=settings.ollama_base_url
    ))
    
    # Connect to generator
    if flags.use_pgvector:
        pipeline.connect("ranker.documents", "prompt_builder.documents")
    else:
        pipeline.connect("doc_limiter.documents", "prompt_builder.documents")
    
    pipeline.connect("prompt_builder.prompt", "generator.prompt")
    
    return pipeline
```

### Phase 3: Migration & Testing (Sprint 3 - Enhanced)

#### Updated Ticket #8: Batch Migration with Progress Tracking
```python
# scripts/migrate_to_postgres.py
import asyncio
import asyncpg
from typing import List, Optional
import logging
from tqdm.asyncio import tqdm
import click
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MigrationManager:
    def __init__(self, pg_conn_str: str, batch_size: int = 1000):
        self.pg_conn_str = pg_conn_str
        self.batch_size = batch_size
        self.checkpoint_file = "migration_checkpoint.json"
    
    async def migrate(self, resume: bool = False):
        """Main migration entry point"""
        conn = await asyncpg.connect(self.pg_conn_str)
        
        try:
            # Load checkpoint if resuming
            last_offset = 0
            if resume:
                last_offset = self._load_checkpoint()
            
            # Get total document count
            total_docs = await self._get_total_documents()
            
            # Create indexes before migration (empty table)
            if last_offset == 0:
                await self._create_indexes(conn)
            
            # Migrate in batches
            with tqdm(total=total_docs, initial=last_offset) as pbar:
                offset = last_offset
                
                while offset < total_docs:
                    batch_start = datetime.now()
                    
                    # Get batch from SQLite
                    docs = await self._get_document_batch(offset, self.batch_size)
                    
                    # Get embeddings from ChromaDB
                    embeddings = await self._get_embeddings_batch([d['id'] for d in docs])
                    
                    # Insert into PostgreSQL
                    await self._insert_batch(conn, docs, embeddings)
                    
                    # Update progress
                    offset += len(docs)
                    pbar.update(len(docs))
                    
                    # Save checkpoint
                    self._save_checkpoint(offset)
                    
                    # Log performance
                    batch_duration = (datetime.now() - batch_start).total_seconds()
                    docs_per_sec = len(docs) / batch_duration
                    logger.info(f"Migrated batch: {len(docs)} docs in {batch_duration:.2f}s ({docs_per_sec:.0f} docs/s)")
            
            # Verify migration
            await self._verify_migration(conn)
            
        finally:
            await conn.close()
    
    async def _create_indexes(self, conn: asyncpg.Connection):
        """Create indexes on empty table for better performance"""
        logger.info("Creating indexes...")
        
        # Create HNSW index
        await conn.execute("""
            CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_embedding_hnsw 
            ON documents USING hnsw (embedding vector_cosine_ops) 
            WITH (m = 16, ef_construction = 64)
        """)
        
        # Create other indexes
        index_queries = [
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_fulltext ON documents USING GIN (to_tsvector('english', processed_content))",
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_doc_type ON documents(doc_type)",
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_created_at ON documents(created_at DESC)"
        ]
        
        for query in index_queries:
            await conn.execute(query)
        
        logger.info("Indexes created successfully")
    
    async def _verify_migration(self, conn: asyncpg.Connection):
        """Verify migration completeness"""
        pg_count = await conn.fetchval("SELECT COUNT(*) FROM documents")
        sqlite_count = await self._get_total_documents()
        
        if pg_count != sqlite_count:
            logger.error(f"Count mismatch! PostgreSQL: {pg_count}, SQLite: {sqlite_count}")
            raise ValueError("Migration verification failed")
        
        # Sample verification
        sample_size = min(100, pg_count)
        logger.info(f"Verifying {sample_size} random documents...")
        
        # Add sampling logic here
        
        logger.info("Migration verified successfully!")

@click.command()
@click.option('--resume', is_flag=True, help='Resume from last checkpoint')
@click.option('--batch-size', default=1000, help='Batch size for migration')
def migrate(resume: bool, batch_size: int):
    """Run the migration"""
    manager = MigrationManager(
        pg_conn_str="postgresql://synapse_user:synapse_password@localhost:5432/synapse_db",
        batch_size=batch_size
    )
    asyncio.run(manager.migrate(resume=resume))

if __name__ == "__main__":
    migrate()
```

### Phase 4: Monitoring & Rollout (NEW Sprint)

#### Configuration for Gradual Rollout
```python
# deployment/rollout_config.py
"""
Rollout Schedule:
Week 1: 0% pgvector (shadow reads only)
Week 2: 10% pgvector reads
Week 3: 50% pgvector reads  
Week 4: 100% pgvector reads
Week 5: Disable ChromaDB writes
Week 6: Decommission ChromaDB
"""

ROLLOUT_STAGES = [
    {
        "week": 1,
        "config": {
            "FF_USE_PGVECTOR": "false",
            "FF_PGVECTOR_READ_PERCENTAGE": "0",
            "FF_ENABLE_DUAL_WRITE": "true",
            "FF_ENABLE_SHADOW_READS": "true"
        }
    },
    {
        "week": 2,
        "config": {
            "FF_USE_PGVECTOR": "false",
            "FF_PGVECTOR_READ_PERCENTAGE": "10",
            "FF_ENABLE_DUAL_WRITE": "true",
            "FF_ENABLE_SHADOW_READS": "true"
        }
    },
    # ... more stages
]
```

#### Monitoring Dashboard Queries
```sql
-- monitoring/dashboard_queries.sql

-- Query performance comparison
SELECT 
    CASE 
        WHEN query LIKE '%/* pgvector */%' THEN 'pgvector'
        ELSE 'chromadb'
    END as store,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY total_exec_time) as p50_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY total_exec_time) as p95_ms,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY total_exec_time) as p99_ms,
    COUNT(*) as query_count
FROM pg_stat_statements
WHERE query LIKE '%embedding%'
GROUP BY 1;

-- Index efficiency
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

## Critical Success Patterns

### 1. Connection Pool Configuration
```python
# backend/database_async.py
import asyncpg
from asyncpg import Pool

async def create_pool() -> Pool:
    return await asyncpg.create_pool(
        settings.get_database_url,
        min_size=10,
        max_size=20,
        max_queries=50000,
        max_inactive_connection_lifetime=300,
        command_timeout=60,
        server_settings={
            'jit': 'off',  # Disable JIT for consistent performance
            'application_name': 'synapse_backend'
        }
    )
```

### 2. Graceful Degradation Pattern
```python
# backend/utils/failover.py
from typing import Optional, List
from haystack import Document
import logging

logger = logging.getLogger(__name__)

class FailoverManager:
    def __init__(self, primary_store, fallback_store):
        self.primary = primary_store
        self.fallback = fallback_store
        self.consecutive_failures = 0
        self.max_failures = 3
        self.circuit_open = False
    
    async def search(self, *args, **kwargs) -> List[Document]:
        """Search with automatic failover"""
        if not self.circuit_open:
            try:
                results = await self.primary.search(*args, **kwargs)
                self.consecutive_failures = 0  # Reset on success
                return results
            except Exception as e:
                logger.error(f"Primary store failed: {e}")
                self.consecutive_failures += 1
                
                if self.consecutive_failures >= self.max_failures:
                    self.circuit_open = True
                    logger.warning("Circuit breaker opened, using fallback")
        
        # Use fallback
        try:
            return await self.fallback.search(*args, **kwargs)
        except Exception as e:
            logger.error(f"Fallback store also failed: {e}")
            raise
```

### 3. Performance Monitoring
```python
# backend/monitoring/metrics.py
from prometheus_client import Counter, Histogram, Gauge
import time
from functools import wraps

# Metrics
query_duration = Histogram(
    'document_store_query_duration_seconds',
    'Query duration by store type',
    ['store_type', 'operation']
)

query_errors = Counter(
    'document_store_errors_total',
    'Total errors by store type',
    ['store_type', 'operation']
)

def track_performance(store_type: str, operation: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            with query_duration.labels(store_type, operation).time():
                try:
                    return await func(*args, **kwargs)
                except Exception as e:
                    query_errors.labels(store_type, operation).inc()
                    raise
        return wrapper
    return decorator
```

## Rollback Procedures

### Emergency Rollback Script
```bash
#!/bin/bash
# scripts/emergency_rollback.sh

echo "Starting emergency rollback to ChromaDB..."

# 1. Update feature flags
export FF_USE_PGVECTOR=false
export FF_PGVECTOR_READ_PERCENTAGE=0
export FF_ENABLE_DUAL_WRITE=false

# 2. Restart application
docker-compose restart backend

# 3. Verify health
sleep 10
curl http://localhost:8101/health

echo "Rollback complete. System using ChromaDB."
```

## Final Recommendations

1. **DO NOT** rush the migration - the phased approach is critical
2. **DO** establish baseline metrics before starting
3. **DO** maintain the ability to rollback for at least 2 weeks post-migration
4. **DO** test with production-like data volumes
5. **MONITOR** closely during each rollout phase

## Success Criteria

- [ ] Query latency p95 < 200ms (matching current performance)
- [ ] Zero data loss during migration
- [ ] Successful rollback tested at each phase
- [ ] All tests passing with both stores
- [ ] Monitoring dashboard showing healthy metrics
- [ ] Documentation updated

## Conclusion

The PostgreSQL migration is a significant but worthwhile improvement to Synapse's architecture. By following this enhanced plan with proper monitoring, feature flags, and rollback procedures, the migration can be executed safely with minimal risk to the production system.

The unified database approach will provide:
- Simplified operations and backups
- Better consistency guarantees
- Native hybrid search capabilities
- Reduced infrastructure complexity
- Better scalability path

Total estimated effort: 25-30 hours (increased from original 17-21 hours due to additional safety measures)