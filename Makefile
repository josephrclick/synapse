# Load environment variables
include .env
export

# Color definitions
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: test run setup clean lint help run-backend run-frontend run-all test-all stop-all logs check-ports \
        check-ollama check-deps check-all status run-all-with-ollama rebuild-all dev-setup \
        validate-setup health-check docker-shell pull-models init fresh-start wait-for-backend wait-for-chromadb \
        check-requirements logs-backend logs-chromadb logs-ollama backup-data run-frontend-background stop-frontend \
        run-all-detached dev getting-started

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

getting-started:  ## Show getting started guide
	@echo "$(YELLOW)🚀 Getting Started with Capture-v3$(NC)"
	@echo ""
	@echo "$(GREEN)First time setup:$(NC)"
	@echo "  1. $(YELLOW)make init$(NC)        - Initialize project from fresh clone"
	@echo "  2. $(YELLOW)make dev$(NC)         - Start all services in background"
	@echo ""
	@echo "$(GREEN)Daily workflow:$(NC)"
	@echo "  - $(YELLOW)make dev$(NC)         - Start development environment"
	@echo "  - $(YELLOW)make status$(NC)      - Check if everything is running"
	@echo "  - $(YELLOW)make logs$(NC)        - View logs from all services"
	@echo "  - $(YELLOW)make stop-all$(NC)    - Stop when done"
	@echo ""
	@echo "$(GREEN)Troubleshooting:$(NC)"
	@echo "  - $(YELLOW)make check-ports$(NC) - Check if ports are available"
	@echo "  - $(YELLOW)make check-deps$(NC)  - Verify all dependencies"
	@echo "  - $(YELLOW)make troubleshoot$(NC) - Interactive troubleshooting"
	@echo ""
	@echo "For all commands: $(YELLOW)make help$(NC)"

init:  ## First time setup for fresh clone (creates configs and installs deps)
	@echo "$(YELLOW)🚀 Initializing Capture-v3 from fresh clone...$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 0: Checking requirements...$(NC)"
	@$(MAKE) check-requirements || { echo "$(RED)Please install missing requirements first$(NC)"; exit 1; }
	@echo ""
	@echo "$(YELLOW)Step 1/5: Creating configuration files...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✅ Created .env from example$(NC)"; \
	else \
		echo "$(GREEN)✅ .env already exists$(NC)"; \
	fi
	@if [ ! -f frontend/capture-v3/.env.local ]; then \
		cp frontend/capture-v3/.env.local.example frontend/capture-v3/.env.local; \
		sed -i 's/your-secret-api-key-here/test-api-key-123/g' frontend/capture-v3/.env.local; \
		echo "$(GREEN)✅ Created frontend .env.local$(NC)"; \
	else \
		echo "$(GREEN)✅ Frontend .env.local already exists$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)2/5: Installing backend dependencies...$(NC)"
	@$(MAKE) setup
	@echo ""
	@echo "$(YELLOW)3/5: Installing frontend dependencies...$(NC)"
	@cd frontend/capture-v3 && npm install
	@echo ""
	@echo "$(YELLOW)4/5: Checking Docker setup...$(NC)"
	@$(MAKE) validate-setup
	@echo ""
	@echo "$(YELLOW)5/5: Pulling Ollama models (optional)...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		$(MAKE) pull-models; \
	else \
		echo "$(YELLOW)⚠️  Ollama not installed - skip model pulling$(NC)"; \
		echo "   Install from https://ollama.ai if you want local LLM support"; \
	fi
	@echo ""
	@echo "$(GREEN)✅ Initialization complete!$(NC)"
	@echo ""
	@echo "🎯 Quick Start Options:"
	@echo "  $(YELLOW)make dev$(NC)          - Start all services in background (recommended)"
	@echo "  $(YELLOW)make run-all$(NC)      - Start all services (frontend blocks terminal)"
	@echo ""
	@echo "📍 Access Points:"
	@echo "  Frontend:    http://localhost:$(FRONTEND_PORT)"
	@echo "  Backend API: http://localhost:$(API_PORT)"
	@echo "  API Docs:    http://localhost:$(API_PORT)/docs"
	@echo ""
	@echo "🛠️  Useful Commands:"
	@echo "  $(YELLOW)make status$(NC)       - Check service status"
	@echo "  $(YELLOW)make logs$(NC)         - View all logs"
	@echo "  $(YELLOW)make stop-all$(NC)     - Stop everything"
	@echo "  $(YELLOW)make help$(NC)         - Show all available commands"
	@echo ""
	@echo "If you have issues, run: $(YELLOW)make troubleshoot$(NC)"

fresh-start:  ## Complete fresh start (clean + init + run)
	@echo "$(YELLOW)🧹 Starting fresh...$(NC)"
	@$(MAKE) clean
	@$(MAKE) init
	@echo ""
	@echo "$(YELLOW)Ready to start services!$(NC)"
	@echo "Run: make run-all"

setup:  ## Setup virtual environment and install dependencies
	@if [ ! -d "venv" ] || [ "backend/requirements.txt" -nt "venv/.deps-installed" ] || [ "backend/requirements-dev.txt" -nt "venv/.deps-installed" ]; then \
		echo "$(YELLOW)Setting up Python environment...$(NC)"; \
		python3 -m venv venv; \
		./venv/bin/pip install --upgrade pip; \
		echo "$(YELLOW)Installing production dependencies...$(NC)"; \
		./venv/bin/pip install -r backend/requirements.txt; \
		echo "$(YELLOW)Installing development dependencies...$(NC)"; \
		./venv/bin/pip install -r backend/requirements-dev.txt; \
		touch venv/.deps-installed; \
		echo "$(GREEN)✅ Dependencies installed successfully$(NC)"; \
	else \
		echo "$(GREEN)✅ Dependencies already installed and up-to-date$(NC)"; \
	fi

run:  ## Start the backend server (alias for run-backend)
	./backend/setup_and_run.sh

run-backend:  ## Start backend API server
	@echo "Starting backend API on port $(API_PORT)..."
	cd backend && ./setup_and_run.sh

run-frontend:  ## Start frontend dev server
	@echo "Starting frontend dev server on port $(FRONTEND_PORT)..."
	cd frontend/capture-v3 && npm run dev

run-frontend-background:  ## Start frontend dev server in background
	@echo "$(YELLOW)Starting frontend dev server in background on port $(FRONTEND_PORT)...$(NC)"
	@cd frontend/capture-v3 && nohup npm run dev > ../../frontend.log 2>&1 & echo $$! > ../../.frontend.pid
	@sleep 2
	@if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
		echo "$(GREEN)✅ Frontend started in background (PID: $$(cat .frontend.pid))$(NC)"; \
		echo "   View logs with: tail -f frontend.log"; \
		echo "   Stop with: make stop-frontend"; \
	else \
		echo "$(RED)❌ Failed to start frontend$(NC)"; \
		[ -f frontend.log ] && tail -20 frontend.log; \
		exit 1; \
	fi

stop-frontend:  ## Stop background frontend server
	@if [ -f .frontend.pid ]; then \
		echo "$(YELLOW)Stopping frontend server...$(NC)"; \
		kill $$(cat .frontend.pid) 2>/dev/null || true; \
		rm -f .frontend.pid; \
		echo "$(GREEN)✅ Frontend stopped$(NC)"; \
	else \
		echo "$(YELLOW)Frontend is not running in background$(NC)"; \
	fi

check-ollama:  ## Check if Ollama is running and available
	@echo "$(YELLOW)Checking Ollama status...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
			echo "$(GREEN)✅ Ollama is running$(NC)"; \
			echo "   Models available:"; \
			curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | sed 's/^/   - /' || echo "   (unable to list models)"; \
			if ! curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | grep -q "$(GENERATIVE_MODEL)"; then \
				echo "$(YELLOW)⚠️  Model $(GENERATIVE_MODEL) not found$(NC)"; \
				echo "   Run: ollama pull $(GENERATIVE_MODEL)"; \
			fi; \
		else \
			echo "$(YELLOW)⚠️  Ollama is installed but not running$(NC)"; \
			echo "   Run 'ollama serve' in another terminal, or:"; \
			echo "   - Linux: sudo systemctl start ollama"; \
			echo "   - macOS: ollama serve"; \
		fi \
	else \
		echo "$(RED)❌ Ollama is not installed$(NC)"; \
		echo "   Visit https://ollama.ai for installation instructions"; \
	fi

check-requirements:  ## Verify all required tools are installed (fails if missing)
	@echo "$(YELLOW)Verifying required tools...$(NC)"
	@command -v python3 >/dev/null 2>&1 || { echo "$(RED)❌ Python3 is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Python3 found$(NC)"
	@command -v npm >/dev/null 2>&1 || { echo "$(RED)❌ npm is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ npm found$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ Docker is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Docker found$(NC)"
	@command -v docker compose version >/dev/null 2>&1 || { echo "$(RED)❌ Docker Compose is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Docker Compose found$(NC)"
	@command -v curl >/dev/null 2>&1 || { echo "$(RED)❌ curl is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ curl found$(NC)"
	@command -v jq >/dev/null 2>&1 || { echo "$(YELLOW)⚠️  jq is recommended but not installed (some features may not work).$(NC)"; }
	@echo "$(GREEN)✅ All required tools are installed!$(NC)"

check-deps:  ## Check all dependencies and services
	@echo "$(YELLOW)Checking system dependencies...$(NC)"
	@echo -n "Docker: "; \
	if command -v docker >/dev/null 2>&1; then \
		echo "$(GREEN)✅ $(shell docker --version)$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "Docker Compose: "; \
	if command -v docker compose >/dev/null 2>&1; then \
		echo "$(GREEN)✅ $(shell docker compose version)$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "Python: "; \
	if command -v python3 >/dev/null 2>&1; then \
		echo "$(GREEN)✅ $(shell python3 --version)$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "Node.js: "; \
	if command -v node >/dev/null 2>&1; then \
		echo "$(GREEN)✅ $(shell node --version)$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "npm: "; \
	if command -v npm >/dev/null 2>&1; then \
		echo "$(GREEN)✅ $(shell npm --version)$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi

check-all:  ## Run all checks (ports, deps, ollama)
	@$(MAKE) check-deps
	@echo ""
	@$(MAKE) check-ports
	@echo ""
	@$(MAKE) check-ollama

status:  ## Show status of all services
	@echo "$(YELLOW)Service Status:$(NC)"
	@echo "Frontend (http://localhost:$(FRONTEND_PORT)):"
	@if curl -s http://localhost:$(FRONTEND_PORT) >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo "Backend API (http://localhost:$(API_PORT)):"
	@if curl -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Running$(NC)"; \
		curl -s http://localhost:$(API_PORT)/health | jq -r '.status' | sed 's/^/  Status: /' 2>/dev/null || true; \
	else \
		echo "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo "ChromaDB (http://localhost:$(CHROMA_GATEWAY_PORT)):"
	@if curl -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1/heartbeat >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo "Ollama (http://localhost:11434):"
	@if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo ""
	@echo "Docker containers:"
	@docker compose ps

run-all:  ## Start all services (docker + frontend) - works from fresh clone
	@echo "$(YELLOW)Preparing environment...$(NC)"
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			echo "Creating .env from .env.example..."; \
			cp .env.example .env; \
			echo "$(GREEN)✅ .env file created$(NC)"; \
		else \
			echo "$(RED)❌ No .env or .env.example found!$(NC)"; \
			echo "Please create a .env file with required variables"; \
			exit 1; \
		fi \
	fi
	@if [ ! -f frontend/capture-v3/.env.local ]; then \
		if [ -f frontend/capture-v3/.env.local.example ]; then \
			echo "Creating frontend .env.local from example..."; \
			cp frontend/capture-v3/.env.local.example frontend/capture-v3/.env.local; \
			sed -i 's/your-secret-api-key-here/test-api-key-123/g' frontend/capture-v3/.env.local; \
			echo "$(GREEN)✅ Frontend .env.local created$(NC)"; \
		fi \
	fi
	@if [ ! -d frontend/capture-v3/node_modules ]; then \
		echo "$(YELLOW)Installing frontend dependencies...$(NC)"; \
		cd frontend/capture-v3 && npm install && cd ../..; \
		echo "$(GREEN)✅ Frontend dependencies installed$(NC)"; \
	fi
	@if [ ! -d backend/venv ]; then \
		echo "$(YELLOW)Setting up Python virtual environment...$(NC)"; \
		$(MAKE) setup; \
		echo "$(GREEN)✅ Backend dependencies installed$(NC)"; \
	fi
	@$(MAKE) check-ports
	@$(MAKE) check-ollama
	@echo "$(YELLOW)Starting all services...$(NC)"
	docker compose up -d
	@echo ""
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo ""
	@$(MAKE) health-check
	@echo ""
	@echo "$(YELLOW)Starting frontend...$(NC)"
	cd frontend/capture-v3 && npm run dev

run-all-detached:  ## Start all services in background (non-blocking)
	@$(MAKE) check-requirements
	@echo "$(YELLOW)Preparing environment...$(NC)"
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			echo "Creating .env from .env.example..."; \
			cp .env.example .env; \
			echo "$(GREEN)✅ .env file created$(NC)"; \
		else \
			echo "$(RED)❌ No .env or .env.example found!$(NC)"; \
			echo "Please create a .env file with required variables"; \
			exit 1; \
		fi \
	fi
	@if [ ! -f frontend/capture-v3/.env.local ]; then \
		if [ -f frontend/capture-v3/.env.local.example ]; then \
			echo "Creating frontend .env.local from example..."; \
			cp frontend/capture-v3/.env.local.example frontend/capture-v3/.env.local; \
			sed -i 's/your-secret-api-key-here/test-api-key-123/g' frontend/capture-v3/.env.local; \
			echo "$(GREEN)✅ Frontend .env.local created$(NC)"; \
		fi \
	fi
	@if [ ! -d frontend/capture-v3/node_modules ]; then \
		echo "$(YELLOW)Installing frontend dependencies...$(NC)"; \
		cd frontend/capture-v3 && npm install && cd ../..; \
		echo "$(GREEN)✅ Frontend dependencies installed$(NC)"; \
	fi
	@if [ ! -d backend/venv ]; then \
		echo "$(YELLOW)Setting up Python virtual environment...$(NC)"; \
		$(MAKE) setup; \
		echo "$(GREEN)✅ Backend dependencies installed$(NC)"; \
	fi
	@$(MAKE) check-ports
	@$(MAKE) check-ollama
	@echo "$(YELLOW)Starting all services...$(NC)"
	docker compose up -d
	@echo ""
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo ""
	@$(MAKE) health-check
	@echo ""
	@$(MAKE) run-frontend-background
	@echo ""
	@echo "$(GREEN)✅ All services are running!$(NC)"
	@echo ""
	@echo "Access points:"
	@echo "  - Frontend: http://localhost:$(FRONTEND_PORT)"
	@echo "  - Backend API: http://localhost:$(API_PORT)"
	@echo "  - API Docs: http://localhost:$(API_PORT)/docs"
	@echo ""
	@echo "Useful commands:"
	@echo "  - View all logs: make logs"
	@echo "  - View frontend logs: tail -f frontend.log"
	@echo "  - Stop all services: make stop-all"
	@echo "  - Check status: make status"

dev:  ## Start development environment (alias for run-all-detached)
	@$(MAKE) run-all-detached

run-all-with-ollama:  ## Start all services including Ollama
	@$(MAKE) check-ports
	@if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
		echo "$(YELLOW)Starting Ollama in background...$(NC)"; \
		nohup ollama serve > ollama.log 2>&1 & \
		echo $$! > .ollama.pid; \
		sleep 3; \
	fi
	@$(MAKE) run-all

rebuild-all:  ## Rebuild all Docker images (no cache) and start services
	@echo "$(YELLOW)Rebuilding all services...$(NC)"
	docker compose down
	docker compose build --no-cache
	@$(MAKE) run-all

dev-setup:  ## Complete development environment setup
	@echo "$(YELLOW)Setting up development environment...$(NC)"
	@$(MAKE) check-deps
	@echo ""
	@echo "$(YELLOW)Installing backend dependencies...$(NC)"
	@$(MAKE) setup
	@echo ""
	@echo "$(YELLOW)Installing frontend dependencies...$(NC)"
	@cd frontend/capture-v3 && npm install
	@echo ""
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo "Run 'make run-all' to start all services"

test:  ## Run backend tests
	./backend/run_tests.sh

test-all:  ## Run all tests (backend + frontend)
	@echo "Running backend tests..."
	cd backend && ./run_tests.sh
	@echo "Running frontend linting..."
	cd frontend/capture-v3 && npm run lint

lint:  ## Run code linting
	./venv/bin/ruff check backend/
	./venv/bin/black --check backend/

validate-setup:  ## Validate the entire setup configuration
	@echo "$(YELLOW)Validating setup...$(NC)"
	@echo -n "Checking .env file: "
	@if [ -f .env ]; then \
		echo "$(GREEN)✅ Found$(NC)"; \
	else \
		echo "$(RED)❌ Missing$(NC)"; \
		exit 1; \
	fi
	@echo -n "Checking backend Dockerfile: "
	@if grep -q "COPY --chown=appuser:appuser \*.py \./" backend/Dockerfile 2>/dev/null; then \
		echo "$(GREEN)✅ Correct$(NC)"; \
	else \
		echo "$(RED)❌ Needs fix (wrong COPY path)$(NC)"; \
		echo "   Run: make fix-dockerfile"; \
	fi
	@echo -n "Checking Docker images: "
	@if docker images | grep -q capture-v3-backend; then \
		echo "$(GREEN)✅ Built$(NC)"; \
		echo "   Built: $$(docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}' | grep capture-v3-backend | head -1)"; \
	else \
		echo "$(YELLOW)⚠️  Not built$(NC)"; \
	fi
	@echo -n "Checking required models: "
	@if curl -s http://localhost:11434/api/tags 2>/dev/null | jq -r '.models[].name' | grep -q "$(GENERATIVE_MODEL)"; then \
		echo "$(GREEN)✅ $(GENERATIVE_MODEL) available$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  $(GENERATIVE_MODEL) not pulled$(NC)"; \
	fi

health-check:  ## Check health of all running services
	@echo "$(YELLOW)Checking service health...$(NC)"
	@echo -n "Backend API: "
	@if curl -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; then \
		health=$$(curl -s http://localhost:$(API_PORT)/health | jq -r '.status' 2>/dev/null); \
		if [ "$$health" = "healthy" ]; then \
			echo "$(GREEN)✅ Healthy$(NC)"; \
		elif [ "$$health" = "degraded" ]; then \
			echo "$(YELLOW)⚠️  Degraded$(NC)"; \
			curl -s http://localhost:$(API_PORT)/health | jq '.dependencies' 2>/dev/null | sed 's/^/  /' || true; \
		else \
			echo "$(RED)❌ Unhealthy$(NC)"; \
		fi \
	else \
		echo "$(RED)❌ Not responding$(NC)"; \
	fi
	@echo -n "ChromaDB: "
	@if curl -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1/heartbeat >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Healthy$(NC)"; \
	else \
		echo "$(RED)❌ Not responding$(NC)"; \
	fi

docker-shell:  ## Open a shell in the backend container
	@echo "$(YELLOW)Opening shell in backend container...$(NC)"
	docker compose exec backend /bin/bash

pull-models:  ## Pull required Ollama models
	@echo "$(YELLOW)Pulling required models...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		echo "Pulling $(GENERATIVE_MODEL)..."; \
		ollama pull $(GENERATIVE_MODEL); \
		echo "Pulling mxbai-embed-large..."; \
		ollama pull mxbai-embed-large; \
		echo "$(GREEN)✅ Models pulled successfully$(NC)"; \
	else \
		echo "$(RED)❌ Ollama not installed$(NC)"; \
	fi

fix-dockerfile:  ## Fix the Dockerfile COPY path issue
	@echo "$(YELLOW)Fixing Dockerfile...$(NC)"
	@cp backend/Dockerfile backend/Dockerfile.bak
	@sed -i 's/COPY --chown=appuser:appuser \*.py backend\//COPY --chown=appuser:appuser *.py .\//g' backend/Dockerfile
	@echo "$(GREEN)✅ Dockerfile fixed$(NC)"
	@echo "   Backup saved to backend/Dockerfile.bak"
	@echo "   Run 'make rebuild-all' to rebuild with the fix"

wait-for-backend:  ## Wait for backend to be healthy
	@echo "$(YELLOW)Waiting for backend to be healthy...$(NC)"
	@timeout=30; \
	counter=0; \
	while ! curl -f -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; do \
		counter=$$((counter + 1)); \
		if [ $$counter -ge $$timeout ]; then \
			echo ""; \
			echo "$(RED)❌ Backend failed to become healthy after $$timeout seconds$(NC)"; \
			echo "Check logs with: make logs-backend"; \
			exit 1; \
		fi; \
		echo -n "."; \
		sleep 1; \
	done; \
	echo ""; \
	echo "$(GREEN)✅ Backend is healthy!$(NC)"

wait-for-chromadb:  ## Wait for ChromaDB to be ready
	@echo "$(YELLOW)Waiting for ChromaDB to be ready...$(NC)"
	@timeout=30; \
	counter=0; \
	while ! curl -f -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1 >/dev/null 2>&1; do \
		counter=$$((counter + 1)); \
		if [ $$counter -ge $$timeout ]; then \
			echo ""; \
			echo "$(RED)❌ ChromaDB failed to become ready after $$timeout seconds$(NC)"; \
			echo "Check logs with: make logs-chromadb"; \
			exit 1; \
		fi; \
		echo -n "."; \
		sleep 1; \
	done; \
	echo ""; \
	echo "$(GREEN)✅ ChromaDB is ready!$(NC)"

stop-all:  ## Stop all docker services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	docker compose down
	@if [ -f .frontend.pid ]; then \
		echo "Stopping frontend..."; \
		kill $$(cat .frontend.pid) 2>/dev/null || true; \
		rm -f .frontend.pid; \
	fi
	@if [ -f .ollama.pid ]; then \
		echo "Stopping Ollama..."; \
		kill $$(cat .ollama.pid) 2>/dev/null || true; \
		rm -f .ollama.pid; \
	fi
	@echo "$(GREEN)✅ All services stopped$(NC)"

logs:  ## View docker logs
	docker compose logs -f

check-ports:  ## Check if required ports are available
	@echo "Checking port availability..."
	@for port in $(FRONTEND_PORT) $(API_PORT) $(CHROMA_GATEWAY_PORT); do \
		if lsof -i :$$port >/dev/null 2>&1; then \
			echo "⚠️  Port $$port is already in use!"; \
			lsof -i :$$port | grep LISTEN; \
		else \
			echo "✅ Port $$port is available"; \
		fi \
	done

logs-backend:  ## View backend container logs
	docker compose logs -f backend

logs-chromadb:  ## View ChromaDB container logs
	docker compose logs -f chromadb

logs-ollama:  ## View Ollama logs (if started via make)
	@if [ -f ollama.log ]; then \
		tail -f ollama.log; \
	else \
		echo "$(YELLOW)No Ollama log file found. Ollama may be running as a system service.$(NC)"; \
		echo "Try: journalctl -u ollama -f"; \
	fi

restart:  ## Restart specific service (usage: make restart service=backend)
	@if [ -z "$(service)" ]; then \
		echo "$(RED)Error: Please specify a service$(NC)"; \
		echo "Usage: make restart service=backend"; \
		echo "Available services: backend, chromadb"; \
	else \
		echo "$(YELLOW)Restarting $(service)...$(NC)"; \
		docker compose restart $(service); \
		echo "$(GREEN)✅ $(service) restarted$(NC)"; \
	fi

ingest-test:  ## Test document ingestion
	@echo "$(YELLOW)Testing document ingestion...$(NC)"
	@curl -X POST http://localhost:$(API_PORT)/api/documents \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: test-api-key-123" \
		-d '{"title": "Test Document", "content": "This is a test document for ingestion.", "source": "test"}' \
		2>/dev/null | jq . || echo "$(RED)❌ Ingestion failed$(NC)"

query-test:  ## Test RAG query
	@echo "$(YELLOW)Testing RAG query...$(NC)"
	@curl -X POST http://localhost:$(API_PORT)/api/chat \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: test-api-key-123" \
		-d '{"message": "What is a test document?", "max_context_documents": 5}' \
		2>/dev/null | jq . || echo "$(RED)❌ Query failed$(NC)"

backup-data:  ## Backup SQLite database and ChromaDB data
	@echo "$(YELLOW)Backing up data...$(NC)"
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@if [ -f backend/capture.db ]; then \
		cp backend/capture.db backups/$(shell date +%Y%m%d_%H%M%S)/; \
		echo "$(GREEN)✅ SQLite database backed up$(NC)"; \
	fi
	@if [ -d chromadb_data ]; then \
		cp -r chromadb_data backups/$(shell date +%Y%m%d_%H%M%S)/; \
		echo "$(GREEN)✅ ChromaDB data backed up$(NC)"; \
	fi
	@echo "Backup saved to: backups/$(shell date +%Y%m%d_%H%M%S)/"

monitor:  ## Live monitoring dashboard (requires watch command)
	@if command -v watch >/dev/null 2>&1; then \
		watch -n 2 -c "make status"; \
	else \
		echo "$(RED)❌ 'watch' command not found$(NC)"; \
		echo "Install with: sudo apt-get install watch (Linux) or brew install watch (macOS)"; \
	fi

debug-env:  ## Show all environment variables
	@echo "$(YELLOW)Environment Configuration:$(NC)"
	@echo "Frontend Port: $(FRONTEND_PORT)"
	@echo "API Port: $(API_PORT)"
	@echo "ChromaDB Port: $(CHROMA_GATEWAY_PORT)"
	@echo "API Container Port: $(API_CONTAINER_PORT)"
	@echo "Generative Model: $(GENERATIVE_MODEL)"
	@echo ""
	@echo "$(YELLOW)Backend Environment:$(NC)"
	@cat backend/.env.development | grep -v '^#' | grep -v '^$$' | sed 's/^/  /'

troubleshoot:  ## Interactive troubleshooting guide
	@echo "$(YELLOW)Troubleshooting Guide$(NC)"
	@echo ""
	@echo "1. If backend won't start:"
	@echo "   - Check Dockerfile: make validate-setup"
	@echo "   - Fix if needed: make fix-dockerfile"
	@echo "   - Rebuild: make rebuild-all"
	@echo ""
	@echo "2. If imports fail:"
	@echo "   - Shell into container: make docker-shell"
	@echo "   - Check files: ls -la /app/"
	@echo "   - Test imports: python -c 'import main'"
	@echo ""
	@echo "3. If Ollama issues:"
	@echo "   - Check status: make check-ollama"
	@echo "   - Pull models: make pull-models"
	@echo "   - Start with app: make run-all-with-ollama"
	@echo ""
	@echo "4. View logs:"
	@echo "   - All: make logs"
	@echo "   - Backend only: make logs-backend"
	@echo "   - ChromaDB only: make logs-chromadb"
	@echo ""
	@echo "Run 'make status' to see current system state"

clean:  ## Clean cache and temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true
	rm -f .ollama.pid ollama.log .frontend.pid frontend.log venv/.deps-installed
	@echo "$(GREEN)✅ Cleaned temporary files$(NC)"

clean-docker:  ## Remove Docker images and volumes (CAUTION: deletes data)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	docker compose down -v --rmi all
	@echo "$(GREEN)✅ Docker cleanup complete$(NC)"