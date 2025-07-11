# CLAUDE.md

This file provides guidance to Claude Code when working with this codebase.

## Project Overview

Synapse is a private, local-first knowledge management system:
- **Frontend**: Next.js 15 with dark mode UI and chat interface
- **Backend**: Python 3.11/FastAPI with Haystack RAG  
- **LLM**: Ollama (containerized) - default model configurable
- **Storage**: SQLite (documents) + ChromaDB (vectors)
- **Containers**: Everything runs in Docker (Ollama, ChromaDB, Backend API)

## Essential Commands

### Most Common
```bash
make init               # First-time setup (creates .env files)
make dev                # Start everything (Docker + frontend)
make stop               # Stop all services
make status             # Show service status and health
make health-detailed    # Show Docker health status for each service
make logs               # View logs from all services
```

### Testing
```bash
./tests/test-all.sh     # Run comprehensive test suite
./tests/test-backend-api.sh  # Quick API tests
```

### Debugging
```bash
make logs-backend       # Backend logs only
make logs-chromadb      # ChromaDB logs only
make logs-ollama        # Ollama logs only
make health-detailed    # Show Docker health status for each service
make troubleshoot       # Interactive troubleshooting guide
docker compose ps       # Check container status
```

## Key Files to Know

### Backend (`/backend`)
- `main.py` - FastAPI app with all endpoints
- `pipelines.py` - Haystack RAG pipeline setup
- `database_async.py` - SQLite operations (async)
- `config.py` - Settings management (Pydantic v2)
- `schemas.py` - Request/response models
- `docker-entrypoint.sh` - Container startup script

### Frontend (`/frontend/synapse`)
- `app/page.tsx` - Chat interface
- `app/ingest/page.tsx` - Document ingestion
- `app/components/chat/` - Chat UI components
- `app/lib/chat-service.ts` - Backend API client
- `app/lib/chat-reducer.ts` - State management

### Configuration
- `.env` - Root configuration (ports)
- `docker-compose.yml` - Container orchestration
- `Makefile` - All automation commands

### Tests (`/tests`)
- `test-all.sh` - Comprehensive test runner
- `test-backend-api.sh` - API endpoint tests
- `test-backend-pytest.sh` - Python unit tests
- `TESTING.md` - Testing documentation

## Docker Setup

All services run in containers with health checks:
```yaml
backend:     localhost:8101 → container:8000 (health: /health endpoint)
chromadb:    localhost:8102 → container:8000 (health: /api/v2/heartbeat)
ollama:      localhost:11434 → container:11434 (health: ollama list)
frontend:    localhost:8100 (not containerized)
```

Services use Docker's native health checks and dependency management.

## API Endpoints

- `POST /api/documents` - Ingest documents (async processing)
- `GET /api/documents` - List with pagination
- `GET /api/documents/{id}` - Get document + status
- `POST /api/chat` - RAG query with context control
- `GET /health` - Service health + dependencies

## Environment Variables

### Root `.env`
```bash
FRONTEND_PORT=8100
API_PORT=8101
CHROMA_GATEWAY_PORT=8102
BACKEND_API_KEY=test-api-key-123
```

### Backend `.env`
```bash
EMBEDDING_MODEL=mxbai-embed-large
GENERATIVE_MODEL=gemma2:9b
OLLAMA_BASE_URL=http://ollama:11434  # Container name
CHROMA_HOST=chromadb                  # Container name
```

## Common Development Tasks

### Pull Ollama Models
```bash
make pull-models  # Pulls both embedding and generative models
# Or manually:
docker compose exec ollama ollama pull mxbai-embed-large
docker compose exec ollama ollama pull gemma2:9b
```

### Check Ollama Models
```bash
docker compose exec ollama ollama list
```

### Reset Everything
```bash
make reset  # Prompts before deleting all data
# Or just ChromaDB:
make stop
docker volume rm synapse_chroma_data
make dev
```

### Update Dependencies
```bash
cd backend
pip install -r requirements.txt
cd ../frontend/synapse
npm install
```

### Development Commands
```bash
make run-backend        # Run backend locally (for development)
make run-frontend       # Run frontend locally (for development)
make test               # Run all tests
make lint               # Run linters
make shell              # Open shell in backend container
```

### Management Commands
```bash
make backup             # Backup data (SQLite + ChromaDB)
make restore            # Restore from backup
make rebuild            # Rebuild containers (no cache)
make restart service=backend  # Restart specific service
make fresh              # Complete fresh start

## Architecture Notes

- **Async Processing**: Document ingestion is async with status tracking
- **Health Management**: Docker-native health checks with automatic container restarts
- **Service Dependencies**: Backend waits for ChromaDB and Ollama to be healthy
- **Security**: API key required, AI responses sanitized with DOMPurify
- **Performance**: ~3-4 second query time with local LLMs
- **Database**: SQLite `synapse.db` (gitignored)

## Current Features

- Document ingestion with async processing
- RAG-powered chat with source citations
- Context limit controls (1-20 documents)
- Dark mode UI with virtual scrolling
- Voice transcription PoC (Deepgram)
- Docker containerization with health checks for all services
- Comprehensive test suite
- Automatic service dependency management

## Next Priorities

1. Document management UI (view, edit, delete)
2. Advanced search with filters
3. Streaming chat responses
4. Better error handling for model downloads
5. Production deployment guide

## Gotchas & Tips

- **First Run**: Ollama needs to download models (~3GB) - use `make pull-models`
- **Memory**: ChromaDB can be memory hungry
- **Ports**: All use 8100-8199 range to avoid conflicts
- **API Key**: Required for all backend requests
- **Model Names**: Must match exactly in Ollama
- **Docker**: Use `docker compose` (v2) not `docker-compose`
- **Health Checks**: Services must be healthy before operations (backup/restore/pull-models)

## MCP Tools

When working on this codebase, use:
- **context7**: For library documentation
- **zen**: For code review, debugging, architecture decisions