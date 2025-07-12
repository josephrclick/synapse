# ChromaDB to pgvector Migration Guide

## Local Development Setup

### 1. Docker Compose Configuration

```yaml
# docker-compose.yml
version: '3.8'

services:
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
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse_user -d synapse_db"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### 2. Database Initialization

```sql
-- init.sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536), -- Adjust dimension based on your model
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search
CREATE INDEX documents_embedding_idx ON documents 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Create index for metadata queries
CREATE INDEX documents_metadata_idx ON documents USING GIN (metadata);

-- Function for similarity search
CREATE OR REPLACE FUNCTION search_documents(
    query_embedding vector(1536),
    match_count INT DEFAULT 5,
    filter JSONB DEFAULT '{}'
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.content,
        d.metadata,
        1 - (d.embedding <=> query_embedding) AS similarity
    FROM documents d
    WHERE d.metadata @> filter
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
```

## Haystack Integration

### 1. Updated Requirements

```python
# requirements.in
haystack-ai>=2.0,<3.0
pgvector-haystack==3.4.0
psycopg2-binary>=2.9,<3.0
sqlalchemy>=2.0,<3.0
numpy>=1.22.5,<2.0.0  # Still need to pin NumPy < 2.0
```

### 2. PGVector Document Store Configuration

```python
# config.py
import os
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore

# For local development
POSTGRES_CONNECTION_STRING = os.getenv(
    "DATABASE_URL",
    "postgresql://synapse_user:synapse_password@localhost:5432/synapse_db"
)

def create_document_store():
    """Create PGVector document store with proper configuration."""
    return PgvectorDocumentStore(
        connection_string=POSTGRES_CONNECTION_STRING,
        table_name="documents",
        embedding_dimension=1536,
        vector_function="cosine_distance",
        recreate_table=False,  # Set to True only for initial setup
        search_strategy="exact_nearest_neighbor",  # or "hnsw" for approximate
    )
```

### 3. Migration Script

```python
# migrate_from_chroma.py
import asyncio
from typing import List, Dict, Any
from haystack import Document
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from chroma_haystack import ChromaDocumentStore

async def migrate_documents(
    chroma_store: ChromaDocumentStore,
    pgvector_store: PgvectorDocumentStore,
    batch_size: int = 100
):
    """Migrate documents from ChromaDB to pgvector."""
    
    # Get all documents from ChromaDB
    print("Fetching documents from ChromaDB...")
    all_docs = chroma_store.get_all_documents()
    
    print(f"Found {len(all_docs)} documents to migrate")
    
    # Process in batches
    for i in range(0, len(all_docs), batch_size):
        batch = all_docs[i:i + batch_size]
        
        # Convert to Haystack Document format if needed
        documents = []
        for doc in batch:
            # Ensure proper Document format
            if not isinstance(doc, Document):
                doc = Document(
                    content=doc.content,
                    meta=doc.meta,
                    embedding=doc.embedding
                )
            documents.append(doc)
        
        # Write to pgvector
        pgvector_store.write_documents(documents)
        print(f"Migrated batch {i//batch_size + 1}/{(len(all_docs) + batch_size - 1)//batch_size}")
    
    print("Migration complete!")

# Usage
if __name__ == "__main__":
    # Initialize stores
    chroma_store = ChromaDocumentStore(
        collection_name="your_collection",
        persist_path="./chroma_db"
    )
    
    pgvector_store = create_document_store()
    
    # Run migration
    asyncio.run(migrate_documents(chroma_store, pgvector_store))
```

## Supabase Deployment

### 1. Supabase Setup

```typescript
// supabase/migrations/001_vector_setup.sql
-- Enable pgvector
create extension if not exists vector;

-- Create documents table with RLS
create table public.documents (
    id uuid primary key default gen_random_uuid(),
    content text not null,
    metadata jsonb default '{}',
    embedding vector(1536),
    user_id uuid references auth.users(id),
    created_at timestamp with time zone default timezone('utc'::text, now()),
    updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Enable RLS
alter table public.documents enable row level security;

-- Create policies
create policy "Users can view own documents"
    on public.documents for select
    using (auth.uid() = user_id);

create policy "Users can insert own documents"
    on public.documents for insert
    with check (auth.uid() = user_id);

-- Create vector similarity function
create or replace function match_documents(
    query_embedding vector(1536),
    match_threshold float default 0.78,
    match_count int default 10,
    user_id uuid default null
)
returns table (
    id uuid,
    content text,
    metadata jsonb,
    similarity float
)
language sql stable
as $$
    select
        documents.id,
        documents.content,
        documents.metadata,
        1 - (documents.embedding <=> query_embedding) as similarity
    from documents
    where 
        1 - (documents.embedding <=> query_embedding) > match_threshold
        and (user_id is null or documents.user_id = user_id)
    order by documents.embedding <=> query_embedding
    limit match_count;
$$;
```

### 2. Environment Configuration

```bash
# .env.production
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key  # For server-side operations

# Direct PostgreSQL connection (for Haystack)
DATABASE_URL=postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres
```

### 3. Vercel Deployment Configuration

```json
// vercel.json
{
  "env": {
    "DATABASE_URL": "@database-url",
    "SUPABASE_URL": "@supabase-url",
    "SUPABASE_ANON_KEY": "@supabase-anon-key"
  },
  "buildCommand": "pip install -r requirements.txt",
  "outputDirectory": "api"
}
```

## Key Advantages Summary

1. **No more version conflicts** - PostgreSQL with pgvector is stable and well-maintained
2. **Single database** - Store vectors, metadata, and relational data together
3. **Better performance** - Especially under concurrent load
4. **Production features** - Backups, replication, RLS, transactions
5. **Supabase benefits** - Auth, real-time, global edge functions
6. **Cost effective** - One database instead of two
7. **Future proof** - PostgreSQL isn't going anywhere

## Performance Tuning Tips

```sql
-- Adjust work_mem for better index build performance
SET maintenance_work_mem = '1GB';

-- Use HNSW index for better query performance (pgvector 0.5.0+)
CREATE INDEX documents_embedding_hnsw_idx ON documents 
USING hnsw (embedding vector_cosine_ops);

-- Partial indexes for filtered queries
CREATE INDEX documents_embedding_published_idx ON documents 
USING ivfflat (embedding vector_cosine_ops)
WHERE metadata->>'status' = 'published';
```

## Monitoring and Maintenance

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE tablename = 'documents';

-- Vacuum and analyze regularly
VACUUM ANALYZE documents;

-- Monitor query performance
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

This migration path provides a robust, scalable solution that eliminates the compatibility issues you've been facing with ChromaDB while providing better performance and features for your RAG application.
