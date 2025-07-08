"""Test that all pipeline components can be imported and initialized."""
import pytest
from unittest.mock import patch, MagicMock

def test_can_import_pipelines_module():
    """Test that the pipelines module can be imported without errors."""
    try:
        from backend import pipelines
        assert hasattr(pipelines, 'get_indexing_pipeline')
        assert hasattr(pipelines, 'get_querying_pipeline')
    except ImportError as e:
        pytest.fail(f"Failed to import pipelines module: {e}")

@patch('backend.pipelines.create_chroma_document_store')
def test_indexing_pipeline_initialization(mock_store):
    """Test that indexing pipeline can be built without runtime errors."""
    mock_store.return_value = MagicMock()
    
    from backend.pipelines import build_indexing_pipeline
    
    try:
        pipeline = build_indexing_pipeline()
        assert pipeline is not None
        assert hasattr(pipeline, 'add_component')
        assert hasattr(pipeline, 'connect')
    except Exception as e:
        pytest.fail(f"Failed to build indexing pipeline: {e}")

@patch('backend.pipelines.create_chroma_document_store')
def test_querying_pipeline_initialization(mock_store):
    """Test that querying pipeline can be built without runtime errors."""
    mock_store.return_value = MagicMock()
    
    from backend.pipelines import build_querying_pipeline
    
    try:
        pipeline = build_querying_pipeline()
        assert pipeline is not None
        assert hasattr(pipeline, 'add_component')
        assert hasattr(pipeline, 'connect')
    except Exception as e:
        pytest.fail(f"Failed to build querying pipeline: {e}")

def test_custom_metadata_processor():
    """Test that CustomMetadataProcessor works correctly."""
    from backend.pipelines import CustomMetadataProcessor
    from haystack import Document
    
    processor = CustomMetadataProcessor()
    docs = [
        Document(content="Test doc 1"),
        Document(content="Test doc 2")
    ]
    
    result = processor.run(documents=docs)
    
    assert "documents" in result
    assert len(result["documents"]) == 2
    
    for idx, doc in enumerate(result["documents"]):
        assert "chunk_id" in doc.meta
        assert "chunk_index" in doc.meta
        assert doc.meta["chunk_index"] == idx