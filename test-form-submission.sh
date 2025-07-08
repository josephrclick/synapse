#!/bin/bash

echo "Testing form submission to backend API..."

# Test data
curl -X POST http://localhost:8000/api/documents \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: test-api-key-123" \
  -d '{
    "type": "general_note",
    "title": "Test Note from Frontend",
    "content": "This is a test note submitted to verify the text ingestion UI is working correctly.",
    "tags": ["test", "frontend", "verification"],
    "source_url": "https://example.com"
  }' | python -m json.tool

echo -e "\n\nTo test the UI manually:"
echo "1. Open http://localhost:3000/ingest in your browser"
echo "2. Fill out the form and submit"
echo "3. Check the backend logs for the submission"