# Capture-v3 Backend

FastAPI-based backend service providing document ingestion and RAG-powered search capabilities.

## Quick Start

```bash
# Automated setup and run
./setup_and_run.sh

# Or manual setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn backend.main:app --reload
```

## API Endpoints

- `POST /api/documents` - Ingest new documents
- `GET /api/documents` - List all documents  
- `GET /api/documents/{doc_id}` - Get specific document
- `POST /api/chat` - Query the knowledge base
- `GET /health` - Service health check with dependency status

API documentation available at http://localhost:8000/docs when running.

## Configuration

Create a `.env` file (see `.env.example`) with:
- `INTERNAL_API_KEY` - API authentication key
- `GENERATIVE_MODEL` - LLM model (default: gemma3n:e2b)
- `EMBEDDING_MODEL` - Embedding model (default: mxbai-embed-large)
- `OLLAMA_BASE_URL` - Ollama server URL
- `CHROMA_HOST/PORT` - ChromaDB connection

## Testing

```bash
./run_tests.sh
```

## Key Features

- Async document processing with status tracking
- Dual database design (SQLite + ChromaDB)
- Automatic retry logic for external services
- Request ID correlation for debugging
- Graceful degradation when ChromaDB unavailable