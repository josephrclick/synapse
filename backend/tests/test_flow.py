"""
Debug-focused test suite for the Capture-v3 API.
Tests document ingestion with async processing and chat functionality.
Uses clear visual markers to show data flow and help with debugging.
"""
import time
import json
import pytest


def test_health(client):
    """Test the health endpoint."""
    print("\n=== TESTING HEALTH ENDPOINT ===")
    
    response = client.get("/health")
    print(f"Status: {response.status_code}")
    
    # Check if we got JSON response
    if response.headers.get('content-type', '').startswith('application/json'):
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    else:
        print(f"Response (non-JSON): {response.text[:200]}...")
    
    assert response.status_code == 200
    print("✓ Health check passed!")


def create_and_process_document(client, headers):
    """Helper function to create and process a document, returning its ID."""
    print("\n=== TESTING DOCUMENT INGESTION ===")
    
    # Create a test document
    doc_data = {
        "type": "general_note",
        "title": "Test Document for RAG Pipeline",
        "content": """This is a test document to verify the RAG pipeline integration.
        It contains information about FastAPI, Haystack, and async processing.
        The system should process this document in the background and update its status.""",
        "tags": ["test", "rag", "integration"]
    }
    
    print("\n=== CREATING DOCUMENT ===")
    response = client.post(
        "/api/documents",
        headers=headers,
        json=doc_data
    )
    
    print(f"Create Status: {response.status_code}")
    assert response.status_code == 202
    
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    doc_id = result["doc_id"]
    print(f"✓ Document created with ID: {doc_id}")
    
    # Poll for document status
    print("\n=== CHECKING PROCESSING STATUS ===")
    for i in range(30):  # Poll for up to 30 seconds
        time.sleep(1)
        status_response = client.get(
            f"/api/documents/{doc_id}",
            headers=headers
        )
        
        assert status_response.status_code == 200
        doc_status = status_response.json()
        current_status = doc_status["status"]
        print(f"Attempt {i+1}: Status = {current_status}")
        
        if current_status == "completed":
            print("✓ Document processed successfully!")
            print(f"Final document: {json.dumps(doc_status, indent=2)}")
            return doc_id  # This is intentionally returned for use in test_chat_flow
        elif current_status == "failed":
            print(f"✗ Document processing failed: {doc_status.get('processing_error')}")
            pytest.fail(f"Document processing failed: {doc_status.get('processing_error')}")
    
    pytest.fail("✗ Timeout waiting for document processing")


def test_document_flow(client, headers):
    """Test document creation and async processing - track from creation through indexing."""
    # Use the helper function and verify it completes successfully
    doc_id = create_and_process_document(client, headers)
    assert doc_id is not None
    print(f"✓ Document flow test completed with doc_id: {doc_id}")


def test_chat_flow(client, headers):
    """Test the chat endpoint - see how queries flow through the RAG pipeline."""
    print("\n=== TESTING CHAT ENDPOINT ===")
    
    # First create and process a document
    doc_id = create_and_process_document(client, headers)
    
    # Wait a bit to ensure indexing is complete
    print("\n=== WAITING FOR INDEXING ===")
    print("Waiting 2 seconds for indexing to propagate...")
    time.sleep(2)
    
    # Test chat with a query about the document
    query = "What information do you have about the RAG pipeline integration?"
    chat_data = {
        "query": query,
        "context_limit": 3
    }
    
    print("\n=== SENDING CHAT QUERY ===")
    print(f"Query: {query}")
    
    response = client.post(
        "/api/chat",
        headers=headers,
        json=chat_data
    )
    
    print(f"Chat Status: {response.status_code}")
    assert response.status_code == 200
    
    result = response.json()
    print(f"Answer: {result['answer']}")
    print(f"Query Time: {result.get('query_time_ms', 'N/A')}ms")
    
    if result.get("sources"):
        print("\n=== SOURCES FOUND ===")
        for i, source in enumerate(result["sources"], 1):
            print(f"  {i}. {source.get('title', 'Untitled')} ({source.get('type', 'Unknown')})")
            print(f"     Preview: {source['content'][:100]}...")
    
    print("✓ Chat query completed successfully!")


def test_document_list(client, headers):
    """Test document listing endpoint - see pagination and filtering in action."""
    print("\n=== TESTING DOCUMENT LIST ===")
    
    response = client.get(
        "/api/documents?limit=5",
        headers=headers
    )
    
    print(f"List Status: {response.status_code}")
    assert response.status_code == 200
    
    result = response.json()
    print(f"Total documents: {result['total']}")
    print(f"Page: {result['page']}, Page size: {result['page_size']}")
    
    if result["documents"]:
        print("\n=== RECENT DOCUMENTS ===")
        for doc in result["documents"][:3]:
            print(f"  - {doc['title']} ({doc['type']}) - Status: {doc['status']}")
            if doc.get('tags'):
                print(f"    Tags: {', '.join(doc['tags'])}")
    
    print("✓ Document listing completed successfully!")


def test_error_cases(client, headers):
    """Test error handling - intentionally break things to see error responses."""
    print("\n=== TESTING ERROR CASES ===")
    
    # Test missing API key
    print("\n--- Testing missing API key ---")
    response = client.get("/api/documents")
    print(f"Status: {response.status_code}")
    assert response.status_code == 403
    print(f"Error: {response.json()}")
    print("✓ Missing API key handled correctly")
    
    # Test invalid API key
    print("\n--- Testing invalid API key ---")
    bad_headers = {"X-API-Key": "invalid-key"}
    response = client.get("/api/documents", headers=bad_headers)
    print(f"Status: {response.status_code}")
    assert response.status_code == 401  # 401 Unauthorized for invalid credentials
    print(f"Error: {response.json()}")
    print("✓ Invalid API key handled correctly")
    
    # Test non-existent document
    print("\n--- Testing non-existent document ---")
    response = client.get("/api/documents/non-existent-id", headers=headers)
    print(f"Status: {response.status_code}")
    assert response.status_code == 404
    print(f"Error: {response.json()}")
    print("✓ Non-existent document handled correctly")
    
    # Test invalid document data
    print("\n--- Testing invalid document data ---")
    invalid_doc = {
        "type": "invalid_type",  # Invalid type
        "title": "",  # Empty title
        "content": "Test"
    }
    response = client.post("/api/documents", headers=headers, json=invalid_doc)
    print(f"Status: {response.status_code}")
    assert response.status_code == 422
    print(f"Error: {response.json()}")
    print("✓ Invalid document data handled correctly")
    
    print("\n=== ALL ERROR CASES PASSED ===")


# Optional: Run all tests in order when file is executed directly
if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])