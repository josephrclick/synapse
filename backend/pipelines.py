"""
RAG Pipeline Implementation using Haystack v2.
Provides indexing and querying pipelines for the Capture-v3 system.
"""
import uuid
import logging
from typing import List, Dict, Any, Optional

from haystack import Pipeline, component, Document
from haystack.components.writers import DocumentWriter
from haystack.components.preprocessors import DocumentSplitter
from haystack.components.embedders import SentenceTransformersTextEmbedder, SentenceTransformersDocumentEmbedder
from haystack.components.builders import PromptBuilder
from haystack.components.generators import HuggingFaceLocalGenerator
from haystack.components.retrievers import InMemoryBM25Retriever
from haystack_integrations.document_stores.chroma import ChromaDocumentStore
from haystack_integrations.components.retrievers.chroma import ChromaEmbeddingRetriever
from haystack_integrations.components.embedders.ollama import OllamaDocumentEmbedder, OllamaTextEmbedder
from haystack_integrations.components.generators.ollama import OllamaGenerator

from .config import settings
from .retry_utils import ollama_retry, chromadb_retry

logger = logging.getLogger(__name__)


@component 
class RetryableOllamaDocumentEmbedder:
    """
    Wrapper around OllamaDocumentEmbedder that adds retry logic.
    """
    def __init__(self, model: str, url: str):
        self.embedder = OllamaDocumentEmbedder(model=model, url=url)
        self.model = model
        self.url = url
    
    @component.output_types(documents=List[Document])
    @ollama_retry
    def run(self, documents: List[Document]) -> Dict[str, Any]:
        """Run the embedder with retry logic."""
        return self.embedder.run(documents)


@component
class RetryableOllamaTextEmbedder:
    """
    Wrapper around OllamaTextEmbedder that adds retry logic.
    """
    def __init__(self, model: str, url: str):
        self.embedder = OllamaTextEmbedder(model=model, url=url)
        self.model = model
        self.url = url
    
    @component.output_types(embedding=List[float])
    @ollama_retry
    def run(self, text: str) -> Dict[str, Any]:
        """Run the embedder with retry logic."""
        return self.embedder.run(text)


@component
class RetryableOllamaGenerator:
    """
    Wrapper around OllamaGenerator that adds retry logic.
    """
    def __init__(self, model: str, url: str, generation_kwargs: Dict[str, Any] = None):
        self.generator = OllamaGenerator(
            model=model,
            url=url,
            generation_kwargs=generation_kwargs or {}
        )
        self.model = model
        self.url = url
    
    @component.output_types(replies=List[str], meta=List[Dict[str, Any]])
    @ollama_retry
    def run(self, prompt: str) -> Dict[str, Any]:
        """Run the generator with retry logic."""
        return self.generator.run(prompt)


@component
class CustomMetadataProcessor:
    """
    Custom Haystack component to add chunk-level metadata.
    Adds chunk_id (UUID) and chunk_index to each document.
    """
    
    @component.output_types(documents=List[Document])
    def run(self, documents: List[Document]) -> Dict[str, Any]:
        """
        Process documents to add chunk metadata.
        
        Args:
            documents: List of Document objects to process
            
        Returns:
            Dictionary with processed documents
        """
        for idx, doc in enumerate(documents):
            # Create a copy of existing metadata or initialize empty dict
            metadata = doc.meta.copy() if doc.meta else {}
            
            # Add chunk-specific metadata
            metadata["chunk_id"] = str(uuid.uuid4())
            metadata["chunk_index"] = idx
            
            # Update document metadata
            doc.meta = metadata
            
        return {"documents": documents}


@component
class DocumentScoreFilter:
    """
    Custom Haystack component to filter documents based on similarity score.
    Removes documents with low relevance scores to improve answer quality.
    """
    
    def __init__(self, min_score: float = 0.25, relative_margin: float = 0.25):
        """
        Initialize the score filter.
        
        Args:
            min_score: Absolute minimum similarity score (0-1 range)
            relative_margin: Keep docs within this margin of the best score
        """
        self.min_score = min_score
        self.relative_margin = relative_margin
    
    @component.output_types(documents=List[Document])
    def run(self, documents: List[Document]) -> Dict[str, Any]:
        """
        Filter documents based on similarity scores.
        
        Args:
            documents: List of Document objects with scores
            
        Returns:
            Dictionary with filtered documents
        """
        if not documents:
            return {"documents": []}
        
        # Get the best score (documents should be sorted by score already)
        best_score = getattr(documents[0], 'score', 1.0)
        relative_threshold = best_score - self.relative_margin
        
        filtered_docs = []
        for doc in documents:
            doc_score = getattr(doc, 'score', 0.0)
            
            # Apply both absolute and relative thresholds
            if doc_score >= self.min_score and doc_score >= relative_threshold:
                filtered_docs.append(doc)
            else:
                logger.debug(f"Filtered out document with score {doc_score:.3f} (best: {best_score:.3f})")
        
        logger.info(f"Score filter: kept {len(filtered_docs)} of {len(documents)} documents")
        
        return {"documents": filtered_docs}


@component
class DocumentLimiter:
    """
    Custom Haystack component to limit the number of documents passed to the LLM.
    This ensures we don't exceed token limits by controlling document count.
    """
    
    def __init__(self, default_limit: int = 5):
        self.default_limit = default_limit
    
    @component.output_types(documents=List[Document])
    def run(self, documents: List[Document], limit: Optional[int] = None) -> Dict[str, Any]:
        """
        Limit the number of documents passed through.
        
        Args:
            documents: List of Document objects to filter
            limit: Maximum number of documents to return (uses default_limit if not specified)
            
        Returns:
            Dictionary with limited documents
        """
        actual_limit = limit if limit is not None else self.default_limit
        # Ensure limit is within valid range
        actual_limit = max(1, min(actual_limit, 20))
        
        # Return only the top documents up to the limit
        limited_docs = documents[:actual_limit] if documents else []
        
        if len(documents) > actual_limit:
            logger.info(f"Limited documents from {len(documents)} to {actual_limit}")
        
        return {"documents": limited_docs}


@chromadb_retry
def create_chroma_document_store() -> ChromaDocumentStore:
    """
    Create and initialize ChromaDocumentStore with retry logic.
    
    Returns:
        Initialized ChromaDocumentStore instance
        
    Raises:
        RuntimeError: If connection to ChromaDB fails after retries
    """
    try:
        # Construct ChromaDB URL
        chroma_url = f"http://{settings.chroma_host}:{settings.chroma_port}"
        
        logger.info(f"Connecting to ChromaDB at {chroma_url}")
        
        # Initialize document store
        document_store = ChromaDocumentStore(
            collection_name=settings.chroma_collection_name,
            host=settings.chroma_host,
            port=settings.chroma_port
        )
        
        # Test connection by attempting to count documents
        try:
            _ = document_store.count_documents()
            logger.info("Successfully connected to ChromaDB")
        except Exception as e:
            logger.warning(f"ChromaDB health check failed: {e}")
            # Continue anyway - the store might still work for writes
        
        return document_store
        
    except Exception as e:
        logger.error(f"Failed to initialize ChromaDocumentStore: {e}")
        raise RuntimeError(f"ChromaDB connection failed: {e}")


def build_indexing_pipeline() -> Pipeline:
    """
    Build the document indexing pipeline.
    
    Pipeline flow:
    1. DocumentSplitter - splits documents into chunks
    2. CustomMetadataProcessor - adds chunk metadata
    3. OllamaDocumentEmbedder - generates embeddings
    4. DocumentWriter - writes to ChromaDB
    
    Returns:
        Configured indexing pipeline
    """
    # Initialize components
    splitter = DocumentSplitter(
        split_by=settings.chunk_split_by,
        split_length=settings.chunk_split_length,
        split_overlap=settings.chunk_split_overlap,
        split_threshold=3  # Minimum chunk size
    )
    
    metadata_processor = CustomMetadataProcessor()
    
    embedder = RetryableOllamaDocumentEmbedder(
        model=settings.embedding_model,
        url=settings.ollama_base_url
    )
    
    document_store = create_chroma_document_store()
    writer = DocumentWriter(document_store=document_store)
    
    # Build pipeline
    pipeline = Pipeline()
    
    # Add components
    pipeline.add_component("splitter", splitter)
    pipeline.add_component("metadata_processor", metadata_processor)
    pipeline.add_component("embedder", embedder)
    pipeline.add_component("writer", writer)
    
    # Connect components
    pipeline.connect("splitter.documents", "metadata_processor.documents")
    pipeline.connect("metadata_processor.documents", "embedder.documents")
    pipeline.connect("embedder.documents", "writer.documents")
    
    logger.info("Indexing pipeline built successfully")
    return pipeline


def build_querying_pipeline() -> Pipeline:
    """
    Build the query/chat pipeline.
    
    Pipeline flow:
    1. OllamaTextEmbedder - embeds the query
    2. ChromaEmbeddingRetriever - retrieves relevant documents
    3. PromptBuilder - builds prompt with context
    4. OllamaGenerator - generates response
    
    Returns:
        Configured querying pipeline
    """
    # Initialize components
    query_embedder = RetryableOllamaTextEmbedder(
        model=settings.embedding_model,
        url=settings.ollama_base_url
    )
    
    document_store = create_chroma_document_store()
    retriever = ChromaEmbeddingRetriever(
        document_store=document_store,
        top_k=50  # Increased from 10 to compensate for no reranking
    )
    
    # Define the prompt template
    prompt_template = """
You are a helpful assistant with access to the user's knowledge base.
Use the following context to answer the user's question.
If you cannot answer based on the context, say so.

Context:
{% for doc in documents %}
---
{{ doc.content }}
{% endfor %}
---

Question: {{ query }}

Answer:"""
    
    prompt_builder = PromptBuilder(template=prompt_template)
    
    # Add score filter and document limiter
    score_filter = DocumentScoreFilter(min_score=0.25, relative_margin=0.25)
    doc_limiter = DocumentLimiter(default_limit=5)
    
    generator = RetryableOllamaGenerator(
        model=settings.generative_model,
        url=settings.ollama_base_url,
        generation_kwargs={
            "temperature": 0.7,
            "num_predict": 512  # Ollama uses num_predict instead of max_tokens
        }
    )
    
    # Build pipeline
    pipeline = Pipeline()
    
    # Add components (with score filter and document limiter)
    pipeline.add_component("query_embedder", query_embedder)
    pipeline.add_component("retriever", retriever)
    pipeline.add_component("score_filter", score_filter)
    pipeline.add_component("doc_limiter", doc_limiter)
    pipeline.add_component("prompt_builder", prompt_builder)
    pipeline.add_component("generator", generator)
    
    # Connect components (retriever → score_filter → doc_limiter → prompt_builder)
    pipeline.connect("query_embedder.embedding", "retriever.query_embedding")
    pipeline.connect("retriever.documents", "score_filter.documents")
    pipeline.connect("score_filter.documents", "doc_limiter.documents")
    pipeline.connect("doc_limiter.documents", "prompt_builder.documents")
    pipeline.connect("prompt_builder.prompt", "generator.prompt")
    
    logger.info("Querying pipeline built successfully")
    return pipeline


# Singleton instances - lazy initialization
_indexing_pipeline = None
_querying_pipeline = None


def get_indexing_pipeline() -> Pipeline:
    """
    Get or create the singleton indexing pipeline.
    
    Returns:
        The indexing pipeline instance
    """
    global _indexing_pipeline
    if _indexing_pipeline is None:
        _indexing_pipeline = build_indexing_pipeline()
    return _indexing_pipeline


def get_querying_pipeline() -> Pipeline:
    """
    Get or create the singleton querying pipeline.
    
    Returns:
        The querying pipeline instance
    """
    global _querying_pipeline
    if _querying_pipeline is None:
        _querying_pipeline = build_querying_pipeline()
    return _querying_pipeline


# Initialize pipelines on module import (optional)
# This can help catch configuration errors early
if settings.environment == "production":
    try:
        logger.info("Pre-initializing pipelines...")
        get_indexing_pipeline()
        get_querying_pipeline()
        logger.info("Pipelines initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize pipelines: {e}")
        # Don't raise - allow the app to start even if pipelines fail