# Database Schema and Architecture Report: PostgreSQL Migration

## 1. Executive Summary

This report outlines the recommended database architecture for the migration from ChromaDB to PostgreSQL, as requested in the project goals. The chosen architecture is based on the comprehensive plan detailed in `docs/tickets/postgresql-migration.md`.

The recommended approach is a **Unified Single-Table Architecture** leveraging PostgreSQL with the `pgvector` extension. This model provides an optimal balance of performance, advanced search capabilities, and long-term extensibility, making it a robust foundation for the Synapse platform. It is designed to handle diverse entity types (e.g., 'jobs', 'interviews', 'medical records') from day one without requiring future schema migrations for each new type.

## 2. Core Requirements Analysis

The new schema successfully addresses the three primary project requirements:

*   **Efficiency:** The use of specialized indexes—HNSW for vector search, GIN for full-text and JSONB search, and B-tree for standard filtering—ensures high performance across all query types.
*   **Search and Retrieval:** The implementation of a hybrid search function, combining semantic (vector) and keyword (full-text) search, provides a state-of-the-art retrieval system. The inclusion of a reranker model in the application logic further refines results for maximum relevance.
*   **Extensibility:** The combination of a `doc_type` discriminator column and a flexible `metadata` JSONB column allows the system to store any number of new entity types without database schema changes, providing a truly universal and extensible data model.

## 3. Proposed Database Schema

The architecture is centered around a single `documents` table.

```sql
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content and Title
    original_content TEXT NOT NULL,
    processed_content TEXT NOT NULL,
    title TEXT NOT NULL,
    
    -- Entity Typing and Metadata
    doc_type VARCHAR(50) NOT NULL, -- e.g., 'job_post', 'interview', 'medical_record'
    metadata JSONB DEFAULT '{}',   -- Flexible fields, e.g., {"salary": 120000}
    
    -- Vector Embedding
    embedding vector(1024),
    embedding_model VARCHAR(100) DEFAULT 'mxbai-embed-large',
    
    -- Status and Timestamps
    processing_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Other fields from migration doc...
    source_url TEXT,
    embedding_version INTEGER DEFAULT 1,
    processing_error TEXT
);
```

### Key Columns Explained:
*   `doc_type`: A simple string that identifies the type of entity. This is the primary mechanism for logically partitioning data.
*   `metadata`: A `JSONB` field that holds all data specific to an entity type. For example, a `job_post` could store `{"company": "Acme Inc", "salary_range": [100000, 150000]}`. This field is both flexible and queryable.
*   `embedding`: A `vector` field to store the semantic embedding generated from the document's content, enabling powerful similarity searches.

## 4. Key Architectural Decisions and Trade-offs

The chosen design is powerful, and it's important to understand the decisions that shape it.

### Decision 1: Unified Table vs. Table-per-Type

*   **Our Approach:** A single `documents` table for all entity types.
*   **The Trade-off:** We are prioritizing **flexibility and rapid development** over rigid database-level data integrity.
    *   **Pro:** New entity types can be introduced instantly by the application. There is no need to wait for a database administrator to perform a schema migration (`CREATE TABLE`). This is ideal for an agile environment.
    *   **Con:** The structure of the `metadata` field is not enforced by the database. The responsibility for ensuring that a `job_post` contains the correct fields falls entirely on the application logic (e.g., Pydantic models).
*   **Conclusion:** This is the correct choice for the project's stated goals. The benefits of flexibility far outweigh the costs for this use case.

### Decision 2: Hardcoded Embedding Dimension

*   **Our Approach:** The `embedding` column is defined as `vector(1024)`, locking in the dimension of the `mxbai-embed-large` model.
*   **The Trade-off:** We are optimizing for a specific, high-performing embedding model.
    *   **Pro:** It simplifies the initial design and ensures compatibility with the chosen model.
    *   **Con:** If we ever decide to change to a model with a different vector dimension, it will require a careful migration process: adding a new column, backfilling embeddings for all existing documents, and updating application code.
*   **Conclusion:** This is a necessary and standard decision in vector database design. The team should be aware of the future migration path should the need arise.

## 5. Conclusion and Next Steps

The proposed architecture is robust, modern, and perfectly aligned with the project's long-term vision. It provides a scalable foundation for building a powerful and intelligent content and entity management system.

The implementation details, sprint plans, and individual tickets are comprehensively covered in `docs/tickets/postgresql-migration.md`. The development team should follow that document as the source of truth for the migration. This report serves to validate that plan and clarify the key architectural decisions made.
