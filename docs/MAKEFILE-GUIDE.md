# Makefile Command Guide for Capture-v3

This guide documents all available Make commands for the Capture-v3 project, organized by category.

## Quick Start

### Fresh Clone (Recommended)
```bash
# Clone and start from scratch
git clone <repo-url>
cd capture-v3
make run-all          # Does EVERYTHING automatically!
```

### Or use the setup wizard:
```bash
make init             # Interactive setup wizard
make run-all          # Start all services
```

### Daily use
```bash
make run-all          # Start all services (auto-setup if needed)
make status           # Check if everything is running
make stop-all         # Stop all services
```

## Service Management

### Starting Services

- `make run-all` - **Smart start** - Auto-creates configs, installs deps, starts everything
- `make run-all-with-ollama` - Start all services including Ollama if not running
- `make run-backend` - Start only the backend API
- `make run-frontend` - Start only the frontend dev server
- `make rebuild-all` - Rebuild Docker images with no cache and start

### First-Time Setup

- `make init` - **Complete setup wizard** - Creates all configs, installs deps, pulls models
- `make fresh-start` - Clean everything and run init (nuclear option)

### Stopping Services

- `make stop-all` - Stop all Docker services and Ollama (if started via make)
- `make restart service=backend` - Restart a specific service

## Health & Status Checks

- `make status` - Show status of all services with health indicators
- `make check-all` - Run all checks (dependencies, ports, Ollama)
- `make check-deps` - Check system dependencies (Docker, Python, Node.js)
- `make check-ports` - Check if required ports are available
- `make check-ollama` - Check Ollama status and available models
- `make health-check` - Detailed health check of running services
- `make validate-setup` - Validate entire setup configuration

## Development Tools

### Setup & Configuration

- `make dev-setup` - Complete development environment setup
- `make setup` - Setup Python virtual environment
- `make fix-dockerfile` - Fix the Dockerfile COPY path issue
- `make pull-models` - Pull required Ollama models

### Testing & Debugging

- `make test` - Run backend tests
- `make test-all` - Run all tests (backend + frontend)
- `make lint` - Run code linting
- `make ingest-test` - Test document ingestion endpoint
- `make query-test` - Test RAG query endpoint
- `make docker-shell` - Open shell in backend container
- `make debug-env` - Show all environment variables

### Logs & Monitoring

- `make logs` - View all Docker logs
- `make logs-backend` - View only backend logs
- `make logs-chromadb` - View only ChromaDB logs
- `make logs-ollama` - View Ollama logs (if started via make)
- `make monitor` - Live monitoring dashboard (updates every 2 seconds)

## Maintenance

- `make clean` - Clean cache and temporary files
- `make clean-docker` - Remove Docker images and volumes (⚠️ DELETES DATA)
- `make backup-data` - Backup SQLite database and ChromaDB data
- `make troubleshoot` - Interactive troubleshooting guide

## Environment Variables

Key environment variables used by the Makefile:
- `FRONTEND_PORT` - Frontend dev server port (default: 8100)
- `API_PORT` - Backend API host port (default: 8101)
- `CHROMA_GATEWAY_PORT` - ChromaDB host port (default: 8102)
- `API_CONTAINER_PORT` - Backend container internal port (default: 8000)
- `GENERATIVE_MODEL` - Ollama model for generation (default: gemma3n:e2b)

## Common Workflows

### First Time Setup (Old Way)
```bash
make dev-setup
make fix-dockerfile
make pull-models
make rebuild-all
```

### First Time Setup (New Way - Recommended)
```bash
make run-all    # That's it! Everything is automatic
```

### From Absolute Zero
```bash
# If you want to see what's happening step by step
make init       # Interactive setup with progress indicators
make run-all    # Start everything
```

### Daily Development
```bash
make check-all        # Verify everything is ready
make run-all          # Start all services
make status           # Confirm everything is running
# ... do development ...
make stop-all         # End of day
```

### Debugging Issues
```bash
make troubleshoot     # See common solutions
make validate-setup   # Check configuration
make docker-shell     # Inspect container
make logs-backend     # View backend logs
```

### Testing Changes
```bash
make test-all         # Run all tests
make ingest-test      # Test document ingestion
make query-test       # Test RAG queries
```

## Color Coding

The Makefile uses colors to indicate status:
- 🟢 Green (✅) - Success/OK
- 🟡 Yellow (⚠️) - Warning/Info
- 🔴 Red (❌) - Error/Failed

## Tips

1. Always run `make check-all` before `make run-all` to catch issues early
2. Use `make monitor` to keep an eye on services during development
3. Run `make validate-setup` after any configuration changes
4. Use `make troubleshoot` when something isn't working
5. The `make fix-dockerfile` command can fix the most common startup issue