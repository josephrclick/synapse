from pydantic import BaseModel, Field, ConfigDict, field_validator
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

try:
    from config import settings
except ImportError:
    from config import settings


# Enums
class DocumentStatus(str, Enum):
    """Document processing status values."""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class DocumentType(str, Enum):
    """Common document types for validation."""
    JOB_POST = "job_post"
    INTERVIEW_NOTE = "interview_note"
    GENERAL_NOTE = "general_note"
    ARTICLE = "article"
    MEETING_NOTE = "meeting_note"
    OTHER = "other"


# API Contract Models
class DocumentCreate(BaseModel):
    """Model for creating a new document via API."""
    type: str = Field(..., max_length=50, description="Type of document, e.g., 'interview_note'")
    title: str = Field(..., min_length=1, max_length=255, description="A human-readable title")
    content: str = Field(..., min_length=1, description="The full text content")
    source_url: Optional[str] = Field(None, max_length=2048, description="The original URL, if applicable")
    tags: Optional[List[str]] = Field(None, max_length=20, description="A list of tags for categorization")
    link_to_doc_id: Optional[str] = Field(None, description="Link this new document to an existing one")
    
    @field_validator('source_url')
    @classmethod
    def validate_url(cls, v: Optional[str]) -> Optional[str]:
        """Validate that the URL has proper format if provided."""
        if v and not v.startswith(('http://', 'https://')):
            raise ValueError('URL must start with http:// or https://')
        return v
    
    @field_validator('content')
    @classmethod
    def validate_content_size(cls, v: str) -> str:
        """Validate that content isn't too large."""
        content_size = len(v.encode('utf-8'))
        max_size = settings.max_content_size
        if content_size > max_size:
            raise ValueError(f'Content size ({content_size} bytes) exceeds limit ({max_size} bytes)')
        return v


# Database Models / Response Models
class Document(BaseModel):
    """Model representing a document record from the database."""
    id: str
    type: str
    title: str
    content: str
    source_url: Optional[str] = None
    status: DocumentStatus
    processing_error: Optional[str] = None
    retry_count: int
    created_at: datetime
    updated_at: datetime
    
    # Note: tags are stored as comma-separated string in DB but exposed as list
    model_config = ConfigDict(from_attributes=True)
    
    @classmethod
    def from_db_row(cls, row: dict) -> "Document":
        """
        Creates a Document model from a database row.
        Handles conversion from SQLite row to Pydantic model.
        """
        # Convert ISO string timestamps to datetime objects
        row_dict = dict(row)
        row_dict["created_at"] = datetime.fromisoformat(row_dict["created_at"])
        row_dict["updated_at"] = datetime.fromisoformat(row_dict["updated_at"])
        
        return cls(**row_dict)


class DocumentResponse(Document):
    """
    Model for API responses that includes additional computed fields.
    Extends the base Document model.
    """
    tags: List[str] = Field(default_factory=list, description="Tags associated with the document")
    linked_document_ids: List[str] = Field(default_factory=list, description="IDs of linked documents")


class DocumentLink(BaseModel):
    """Model representing a link between two documents."""
    source_doc_id: str
    target_doc_id: str
    
    model_config = ConfigDict(from_attributes=True)


# Additional response models
class DocumentListResponse(BaseModel):
    """Response model for listing multiple documents."""
    documents: List[DocumentResponse]
    total: int
    page: int = 1
    page_size: int = 20


class IngestionResponse(BaseModel):
    """Response model for document ingestion operations."""
    message: str
    doc_id: str
    status: DocumentStatus = DocumentStatus.PENDING


# Chat Models
class ChatRequest(BaseModel):
    """Model for chat/query requests."""
    query: str = Field(..., min_length=1, max_length=1000, description="The user's question or query")
    context_limit: Optional[int] = Field(5, ge=1, le=20, description="Maximum number of context documents to retrieve")
    
    @field_validator('query')
    @classmethod
    def validate_query(cls, v: str) -> str:
        """Validate that query is not just whitespace."""
        if not v.strip():
            raise ValueError('Query cannot be empty or just whitespace')
        return v.strip()


class ChatResponse(BaseModel):
    """Model for chat/query responses."""
    answer: str = Field(..., description="The generated answer based on the knowledge base")
    sources: Optional[List[Dict[str, Any]]] = Field(None, description="Source documents used to generate the answer")
    query_time_ms: Optional[int] = Field(None, description="Time taken to process the query in milliseconds")