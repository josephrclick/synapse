# Synapse Testing Guide

This guide explains how to run tests for the Synapse knowledge management system. The tests have been refactored to work with the new Docker containerized setup.

## Quick Start

Run all tests with one command:
```bash
./tests/test-all.sh
```

This will check prerequisites, run API tests, optionally run pytest, and test the frontend.

## Test Scripts Overview

### 1. Backend API Tests (`test-backend-api.sh`)
Simple curl-based tests that verify the API is working correctly:
- Health check endpoint
- API key validation 
- Document creation and processing
- Chat/RAG queries
- Document listing
- Error handling

**Run it:**
```bash
./tests/test-backend-api.sh
```

### 2. Pytest Suite (`test-backend-pytest.sh`)
Runs the comprehensive Python test suite inside the Docker container:
- Avoids dependency issues on host machine
- Tests full API workflow
- Includes async processing tests

**Run it:**
```bash
./tests/test-backend-pytest.sh
```

### 3. Frontend Tests (`test-frontend.sh`)
Basic HTTP tests for the frontend:
- Checks if frontend is accessible
- Tests main page and ingestion page
- Verifies static assets
- Checks backend configuration

**Run it:**
```bash
./tests/test-frontend.sh
```

### 4. Form Submission Test (`test-form-submission.sh`)
Tests document ingestion via direct API call:
```bash
./tests/test-form-submission.sh
```

## Prerequisites

1. **Docker must be running**
   ```bash
   docker info  # Should work without errors
   ```

2. **Start all services**
   ```bash
   make dev  # Starts Docker containers + frontend
   ```

3. **Verify services are healthy**
   ```bash
   docker compose ps  # All should show "healthy"
   ```

## Running Tests Manually

### Test the API with curl
```bash
# Health check
curl -H "X-API-Key: test-api-key-123" http://localhost:8101/health

# Create a document
curl -X POST http://localhost:8101/api/documents \
  -H "X-API-Key: test-api-key-123" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "general_note",
    "title": "Test Note",
    "content": "Testing the API",
    "tags": ["test"]
  }'

# Query with chat
curl -X POST http://localhost:8101/api/chat \
  -H "X-API-Key: test-api-key-123" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What do you know about testing?",
    "context_limit": 5
  }'
```

### Test the Frontend
1. Open http://localhost:8100 in your browser
2. Try the chat interface
3. Navigate to /ingest and submit a document
4. Check browser console for errors (F12)

### Run Python Tests Locally (Advanced)
If you want to run pytest on your host machine:
```bash
cd backend
source ../venv/bin/activate  # Or create new venv
pip install -r requirements.txt
pip install -r requirements-dev.txt
pytest tests/ -v -s
```

## Troubleshooting

### Backend tests fail
```bash
# Check if backend is running
docker compose ps backend

# Check backend logs
docker compose logs backend -f

# Restart backend
docker compose restart backend
```

### Frontend tests fail
```bash
# Make sure frontend is running
cd frontend/synapse && npm run dev

# Check for port conflicts
lsof -i :8100
```

### Pytest fails in container
```bash
# Check container has pytest installed
docker compose exec backend pip list | grep pytest

# Run interactively
docker compose exec backend bash
cd /app
pytest tests/ -v -s
```

### API key errors
Make sure your `.env` file has:
```
BACKEND_API_KEY=test-api-key-123
```

## What Changed from Original Tests

1. **Containerized Ollama**: Backend now connects to Ollama container instead of host
2. **Updated ports**: Using 8100-8199 range to avoid conflicts
3. **Docker-based pytest**: Can run tests inside container to avoid dependency issues
4. **Simplified scripts**: Focus on manual testing that's easy to understand
5. **No pre-commit hooks**: Just simple scripts you run when needed

## Next Steps

1. Run `./tests/test-all.sh` to verify everything works
2. Use individual test scripts for specific testing
3. Check `docker compose logs -f` to debug issues
4. For development, keep tests simple and focused on your needs

Remember: These are hobby project tests - they're meant to be quick, dirty, and useful!