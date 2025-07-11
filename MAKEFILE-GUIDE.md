# Makefile Command Guide for Synapse

This guide documents all available Make commands for the Synapse project, organized by category.

## Quick Start

### Fresh Clone (Recommended)
```bash
# Clone and start from scratch
git clone <repo-url>
cd synapse
make init             # First-time setup
make dev              # Start all services
```

### Daily use
```bash
make dev              # Start all services in background
make status           # Show service status and health
make stop             # Stop all services
make logs             # View logs from all services
```

## Service Management

### Starting Services

- `make dev` - **Recommended** - Start all services in background
- `make run-backend` - Run backend locally (for development)
- `make run-frontend` - Run frontend locally (for development)

### First-Time Setup

- `make init` - Initialize project (creates .env files, installs dependencies)
- `make fresh` - Complete fresh start (clean + init + dev)

### Stopping Services

- `make stop` - Stop all services
- `make restart service=backend` - Restart a specific service (backend, chromadb, ollama)

## Health & Status Checks

- `make status` - Show service status and health
- `make health` - Show detailed health status
- `make check-requirements` - Verify required tools are installed
- `make check-ports` - Check if required ports are available

## Development Tools

### Setup & Configuration

- `make pull-models` - Pull required Ollama models
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