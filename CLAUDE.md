# CLAUDE.md

This file provides guidance to Claude Code when working with this codebase.

## Project Overview

Synapse is a private, local-first knowledge management system with:
- **Frontend**: Next.js 15 with dark mode UI and chat interface
- **Backend**: Python 3.11/FastAPI with Haystack RAG  
- **LLM**: Ollama (host OS) - currently using gemma3n:e4b
- **Storage**: SQLite (documents) + ChromaDB (vectors)

## Current State (Phase 2 Complete ✅)

### Phase 1 ✅
- Backend API fully functional with all endpoints
- Frontend can ingest documents and displays status
- RAG pipeline operational for document search
- Test suite passing with good coverage
- Dark mode UI implemented

### Phase 2 ✅
- Chat interface with real-time querying
- Source citations with expandable details
- Context limit controls (1-20 documents)
- Loading states and error handling
- CORS configuration for frontend-backend communication
- Fixed Ollama parameter deprecation warnings
- **Security**: XSS protection with DOMPurify for AI responses
- **Performance**: Virtual scrolling for chat messages using react-virtuoso
- **Port Configuration**: Centralized in root .env (8100-8199 range)
- **Voice PoC**: Push-to-talk transcription with Deepgram SDK (interview prep)

## Quick Commands

### All Services (Recommended)
```bash
make init               # First-time setup (creates .env files)
make run-all            # Start Docker services + frontend dev server
make check-ports        # Verify ports are available
make stop-all           # Stop all Docker services
make logs               # View Docker logs
```

### Backend Only
```bash
cd backend
./setup_and_run.sh      # Full setup and run (uses API_CONTAINER_PORT)
./run_tests.sh          # Run test suite
pip install -r requirements.txt  # Install deps in venv
```

### Frontend Only
```bash
cd frontend/synapse
npm run dev             # Development server (http://localhost:8100)
npm run build           # Production build
npm run lint            # Run ESLint
```

### Environment Setup

#### Root `.env` (centralized port configuration):
```bash
# Application Ports (Host-side)
FRONTEND_PORT=8100
API_PORT=8101
CHROMA_GATEWAY_PORT=8102

# Container Ports (Internal)
API_CONTAINER_PORT=8000
CHROMA_CONTAINER_PORT=8000
```

#### Frontend `.env.local`:
```bash
NEXT_PUBLIC_BACKEND_URL=http://localhost:8101
NEXT_PUBLIC_BACKEND_API_KEY=test-api-key-123

# Deepgram Voice PoC (NOT FOR PRODUCTION!)
NEXT_PUBLIC_DEEPGRAM_API_KEY=your-deepgram-api-key-here
```

## Key Files & Patterns

### Backend Structure
- `main.py` - FastAPI app with all endpoints
- `pipelines.py` - Haystack RAG pipeline setup
- `database.py` / `database_async.py` - SQLite operations (sync/async)
- `config.py` - Settings management (Pydantic v2)
- `schemas.py` - Request/response models
- **Database**: Now uses `synapse.db` (not capture.db)

### Frontend Structure
- `app/page.tsx` - Home page with chat interface
- `app/ingest/` - Document ingestion form
- `app/globals.css` - Dark mode styles
- `app/components/chat/` - Chat UI components
- `app/components/voice/` - Voice transcription components (PoC)
- `app/lib/chat-reducer.ts` - State management
- `app/lib/chat-service.ts` - API communication
- `app/types/chat.ts` - TypeScript interfaces

## API Endpoints

- `POST /api/documents` - Ingest documents
- `GET /api/documents` - List documents
- `GET /api/documents/{id}` - Get specific document  
- `POST /api/chat` - Query knowledge base
- `GET /health` - Health check with deps status

## Testing & Quality

- Run `backend/run_tests.sh` for full test suite
- Tests use proper fixtures and async patterns
- Linting: `ruff check .` and `ruff format .`

## Common Tasks

### Change AI Model
Edit `backend/.env`:
```
GENERATIVE_MODEL=gemma3n:e4b
```

### Fix Missing Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### Debug RAG Pipeline
Check logs for request IDs - all operations are correlated.

## Next Priorities

1. Document management UI (view, edit, delete)
2. Advanced search with filters
3. Tag management and filtering
4. Export functionality
5. Audio ingestion with Deepgram (PoC complete)
6. Streaming chat responses
7. Multi-user support

## MCP Tools to Use

- **context7**: Check for library docs and examples
- **zen**: Get second opinions, debugging help, code review

## Important Notes

- System degrades gracefully if ChromaDB is down
- All models configurable via environment variables
- API requires X-API-KEY header authentication
- Frontend uses client-side fetch with CORS enabled
- Ollama manages GPU/CPU memory automatically
- Chat queries take ~3-4 seconds with local LLMs
- **Ports**: All services use 8100-8199 range to avoid conflicts
- **Security**: AI responses are sanitized with DOMPurify
- **Docker Builds**: Can be slow due to ML dependencies (~800MB)
- **Voice PoC**: Deepgram API key exposed in browser - NOT FOR PRODUCTION
  - Located in `/app/components/voice/DeepgramPocButton.tsx`
  - Push-to-talk using pointer events
  - 250ms MediaRecorder chunks for low latency
  - Browser compatibility: Chrome, Edge, Firefox (no Safari)
- **Database**: SQLite database is now `synapse.db` (was capture.db)
- **Git**: Database files (*.db) are gitignored for privacy

## Ollama Performance

- Embedding model: mxbai-embed-large (334M params)
- Generative model: gemma3n:e2b (2.6GB)
- GPU: AMD Radeon Graphics (4GB VRAM)
- Ollama intelligently offloads layers between GPU/CPU based on available memory