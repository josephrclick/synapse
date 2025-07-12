# Makefile Command Guide for Synapse

This guide documents all available Make commands for the Synapse project, organized by category.

## Quick Start

### First Time Setup
```bash
git clone <repo-url>
cd synapse
make init    # Initialize project (creates .env files, installs dependencies)
make dev     # Start all services (interactive model management included)
```

### Daily Use
```bash
make dev     # Start all services in background
make status  # Show service status and health
make stop    # Stop all services
make logs    # View logs from all services
```

## Service Management

### Starting Services
- `make dev` - **Recommended** - Start all services with interactive port and model checking
- `make run-backend` - Run backend locally (for development)
- `make run-frontend` - Run frontend locally (for development)

### Setup Commands
- `make init` - Initialize project (creates .env files, installs dependencies)
- `make fresh` - Complete fresh start (clean + init + dev)

### Stopping Services
- `make stop` - Stop all services (including frontend)
- `make restart service=backend` - Restart a specific service (backend, chromadb, ollama)
- `make kill-frontend` - Force kill any process using the frontend port

## Health & Status Checks
- `make status` - Show service status and health (shows frontend PID if managed by Makefile)
- `make health` - Show detailed health status
- `make health-detailed` - Show Docker health status for each service
- `make check-requirements` - Verify required tools are installed
- `make check-ports` - Check if required ports are available (interactive for frontend)

## Model Management

### Ollama Model Commands
- `make check-models` - Check which Ollama models are installed
- `make pull-models` - Pull all required Ollama models
- `make interactive-pull-models` - Interactive model management with selection menu

### Required Models
- `gemma3n:e2b` - Generative AI model (for chat responses)
- `mxbai-embed-large` - Embedding model (for document search)
- `linux6200/bge-reranker-v2-m3` - Reranker model (for search result ranking)

## Development Tools

### Setup & Configuration
- `make shell` - Open shell in backend container

### Testing & Debugging
- `make test` - Run all tests
- `make lint` - Run linters
- `make troubleshoot` - Interactive troubleshooting guide

### Logs & Monitoring
- `make logs` - View logs from all services
- `make logs-backend` - View backend logs
- `make logs-chromadb` - View ChromaDB logs
- `make logs-ollama` - View Ollama logs

## Maintenance
- `make clean` - Clean temporary files and caches
- `make reset` - Reset all services and data (prompts for confirmation)
- `make backup` - Backup data (SQLite + ChromaDB)
- `make restore` - Restore from backup
- `make rebuild` - Rebuild containers (no cache)

## Interactive Features

### Port 8100 Handling
When running `make dev`, if port 8100 (frontend) is in use, you'll get an interactive prompt:
```
⚠️  Port 8100 is in use
Options:
  1) Stop frontend and retry
  2) Proceed without starting frontend
  3) Skip check and attempt to start anyway
```

The Makefile now reliably detects ports using both IPv4 and IPv6, utilizing `ss` (socket statistics) as the primary method with `lsof` as a fallback.

### Model Management
During `make dev`, if required models are missing, you'll see:
```
Missing models:
  1) gemma3n:e2b - Generative AI model (for chat responses)
  2) mxbai-embed-large - Embedding model (for document search)
  3) linux6200/bge-reranker-v2-m3 - Reranker model (for search result ranking)
  A) Pull all missing models
  S) Skip for now
```

## Environment Variables

Key environment variables used by the Makefile:
- `FRONTEND_PORT` - Frontend dev server port (default: 8100)
- `API_PORT` - Backend API host port (default: 8101)
- `CHROMA_GATEWAY_PORT` - ChromaDB host port (default: 8102)
- `GENERATIVE_MODEL` - Ollama model for generation (default: gemma3n:e2b)

## Common Workflows

### First Time Setup
```bash
make init       # Initialize project with dependencies
make dev        # Start everything (will prompt for model downloads)
```

### Daily Development
```bash
make dev        # Start all services
make status     # Confirm everything is running (shows frontend PID)
# ... do development ...
make stop       # Stop all services including frontend
```

### Debugging Issues
```bash
make troubleshoot      # Interactive troubleshooting guide
make health-detailed   # Check Docker health status
make logs-backend      # View backend logs
make check-models      # Verify installed models
make kill-frontend     # Force kill frontend if stuck on port 8100
```

### Model Management
```bash
make check-models              # See what's installed
make interactive-pull-models   # Interactive model selection
make pull-models              # Pull all required models
```

## Tips

1. The `make dev` command now handles everything automatically:
   - Checks ports and offers alternatives if port 8100 is busy
   - Verifies Ollama models and prompts to download missing ones
   - Waits for all services to be healthy before proceeding
   - Displays frontend PID when started successfully

2. Use `make health-detailed` to see Docker's native health check status for each service

3. If frontend port is busy, you can:
   - Choose to retry after stopping the blocking service
   - Proceed without frontend (backend services will still start)
   - Use `make kill-frontend` to force kill any process on port 8100

4. Frontend Process Management:
   - Frontend PID is tracked in `.frontend.pid` file
   - `make status` shows if frontend is Makefile-managed or externally managed
   - `make stop` gracefully stops the frontend process
   - Frontend startup waits up to 10 seconds for the port to be ready

5. Port Detection:
   - The Makefile uses `ss` (socket statistics) for reliable port detection
   - Supports both IPv4 and IPv6 connections
   - Falls back to `lsof` if `ss` is not available
   - Next.js frontend typically binds to IPv4 `0.0.0.0:8100` with `--hostname 0.0.0.0`

6. Models are large (~3-5GB each), so the first download may take time

7. All services run in Docker containers except the frontend (for hot-reload during development)