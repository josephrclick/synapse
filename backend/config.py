from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional
import os
from pathlib import Path


class Settings(BaseSettings):
    """
    Configuration settings for Capture-v3 Engine.
    Loads from environment variables or .env file.
    
    Environment-specific configs can be loaded by setting ENVIRONMENT variable:
    - development: .env.development
    - staging: .env.staging
    - production: .env.production
    
    Base .env file is always loaded first, then environment-specific overrides.
    """
    
    # API Security
    internal_api_key: str = Field(..., description="Internal API key for authentication")
    
    # External Service API Keys
    deepgram_api_key: Optional[str] = Field(None, description="Deepgram API key for speech-to-text")
    
    # Model Names
    generative_model: str = Field(default="gemma3n:e4b", description="Generative model name")
    embedding_model: str = Field(default="mxbai-embed-large", description="Embedding model name")
    reranker_model: str = Field(default="BAAI/bge-reranker-v2-m3", description="Reranker model name")
    
    # Ollama Configuration
    ollama_base_url: str = Field(default="http://host.docker.internal:11434", description="Ollama API base URL")
    
    # ChromaDB Configuration
    chroma_host: str = Field(default="chromadb", description="ChromaDB host")
    chroma_port: int = Field(default=8000, description="ChromaDB port")
    chroma_collection_name: str = Field(default="knowledge_base", description="ChromaDB collection name")
    
    # SQLite Configuration
    sqlite_db_path: str = Field(default="./capture.db", description="SQLite database path")
    
    # Chunking Configuration
    chunk_split_by: str = Field(default="sentence", description="How to split documents")
    chunk_split_length: int = Field(default=10, description="Number of units per chunk")
    chunk_split_overlap: int = Field(default=2, description="Overlap between chunks")
    
    # Application Settings
    app_name: str = Field(default="Capture-v3 Engine", description="Application name")
    environment: str = Field(default="development", description="Environment (development/production)")
    log_level: str = Field(default="INFO", description="Logging level")
    max_content_size: int = Field(default=1_000_000, description="Maximum document content size in bytes (default 1MB)")
    
    # Feature Flags
    use_async_db: bool = Field(default=False, description="Use async database operations with connection pooling")
    
    # Testing
    testing: bool = Field(default=False, description="Running in test mode")
    
    model_config = {
        # Look for env files in the backend directory
        "env_file": [
            str(Path(__file__).parent / ".env"),
            str(Path(__file__).parent / f".env.{os.getenv('ENVIRONMENT', 'development')}")
        ],
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
        "extra": "ignore"
    }


# Create a singleton instance
# Pydantic will automatically load from env_file list defined in Config class
settings = Settings()