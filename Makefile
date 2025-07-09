# ========================================================================
# Synapse Makefile
# ========================================================================
# A comprehensive build system for the Synapse knowledge management system
# 
# Features:
# - Cross-platform compatibility (Linux/macOS)
# - Automated dependency management
# - Docker Compose service orchestration
# - Health checking and monitoring
# - Data backup and restore
# - Development workflow automation
#
# Quick Start:
#   make init    # First time setup
#   make dev     # Start all services
#   make help    # Show all commands
#
# Requirements:
# - Python 3.11+
# - Node.js 18+
# - Docker & Docker Compose
# - curl (for health checks)
# ========================================================================

# Shell configuration for error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Platform detection for cross-platform compatibility
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    SED_INPLACE := sed -i ''
else
    SED_INPLACE := sed -i
endif

# Path definitions to avoid duplication
FRONTEND_DIR ?= frontend/synapse
BACKEND_DIR ?= backend

# Load environment variables (if exists)
-include .env
export

# Default values for critical variables (in case .env is missing)
FRONTEND_PORT ?= 8100
API_PORT ?= 8101
CHROMA_GATEWAY_PORT ?= 8102
API_CONTAINER_PORT ?= 8000
GENERATIVE_MODEL ?= gemma3n:e4b

# Color definitions
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: test run setup clean lint help run-backend run-frontend run-all test-all stop-all logs check-ports \
        check-ollama check-deps check-all status run-all-with-ollama rebuild-all dev-setup \
        validate-setup health-check docker-shell pull-models init fresh-start wait-for-backend wait-for-chromadb \
        check-requirements logs-backend logs-chromadb logs-ollama backup-data restore-data run-frontend-background stop-frontend \
        run-all-detached dev getting-started ensure-env-files ensure-backend-env ensure-frontend-env docs \
        run-debug run-prod build-with-cache security-check coffee

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

getting-started:  ## Show getting started guide
	@echo -e "$(YELLOW)🚀 Getting Started with Synapse$(NC)"
	@echo -e ""
	@echo -e "$(GREEN)First time setup:$(NC)"
	@echo -e "  1. $(YELLOW)make init$(NC)        - Initialize project from fresh clone"
	@echo -e "  2. $(YELLOW)make dev$(NC)         - Start all services in background"
	@echo -e ""
	@echo -e "$(GREEN)Daily workflow:$(NC)"
	@echo -e "  - $(YELLOW)make dev$(NC)         - Start development environment"
	@echo -e "  - $(YELLOW)make status$(NC)      - Check if everything is running"
	@echo -e "  - $(YELLOW)make logs$(NC)        - View logs from all services"
	@echo -e "  - $(YELLOW)make stop-all$(NC)    - Stop when done"
	@echo -e ""
	@echo -e "$(GREEN)Troubleshooting:$(NC)"
	@echo -e "  - $(YELLOW)make check-ports$(NC) - Check if ports are available"
	@echo -e "  - $(YELLOW)make check-deps$(NC)  - Verify all dependencies"
	@echo -e "  - $(YELLOW)make troubleshoot$(NC) - Interactive troubleshooting"
	@echo -e ""
	@echo -e "For all commands: $(YELLOW)make help$(NC)"

init:  ## First time setup for fresh clone (creates configs and installs deps)
	@echo -e "$(YELLOW)🚀 Initializing Synapse from fresh clone...$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Step 0: Checking requirements...$(NC)"
	@$(MAKE) check-requirements || { echo -e "$(RED)Please install missing requirements first$(NC)"; exit 1; }
	@echo -e ""
	@echo -e "$(YELLOW)Step 1/5: Creating configuration files...$(NC)"
	@$(MAKE) ensure-env-files
	@echo -e ""
	@echo -e "$(YELLOW)2/5: Installing backend dependencies...$(NC)"
	@$(MAKE) setup
	@echo -e ""
	@echo -e "$(YELLOW)3/5: Installing frontend dependencies...$(NC)"
	@cd $(FRONTEND_DIR) && npm install
	@echo -e ""
	@echo -e "$(YELLOW)4/5: Checking Docker setup...$(NC)"
	@$(MAKE) validate-setup
	@echo -e ""
	@echo -e "$(YELLOW)5/5: Pulling Ollama models (optional)...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		$(MAKE) pull-models; \
		echo -e ""; \
		echo -e "$(YELLOW)📌 Important: Start Ollama with Docker-compatible binding:$(NC)"; \
		echo -e "   $(YELLOW)make start-ollama$(NC)  or  $(YELLOW)OLLAMA_HOST=0.0.0.0:11434 ollama serve$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  Ollama not installed - skip model pulling$(NC)"; \
		echo -e "   Install from https://ollama.ai if you want local LLM support"; \
	fi
	@echo -e ""
	@echo -e "$(GREEN)✅ Initialization complete!$(NC)"
	@echo -e ""
	@echo -e "🎯 Quick Start Options:"
	@echo -e "  $(YELLOW)make dev$(NC)          - Start all services in background (recommended)"
	@echo -e "  $(YELLOW)make run-all$(NC)      - Start all services (frontend blocks terminal)"
	@echo -e ""
	@echo -e "📍 Access Points:"
	@echo -e "  Frontend:    http://localhost:$(FRONTEND_PORT)"
	@echo -e "  Backend API: http://localhost:$(API_PORT)"
	@echo -e "  API Docs:    http://localhost:$(API_PORT)/docs"
	@echo -e ""
	@echo -e "🛠️  Useful Commands:"
	@echo -e "  $(YELLOW)make status$(NC)       - Check service status"
	@echo -e "  $(YELLOW)make logs$(NC)         - View all logs"
	@echo -e "  $(YELLOW)make stop-all$(NC)     - Stop everything"
	@echo -e "  $(YELLOW)make help$(NC)         - Show all available commands"
	@echo -e ""
	@echo -e "If you have issues, run: $(YELLOW)make troubleshoot$(NC)"

fresh-start:  ## Complete fresh start (clean + init + run)
	@echo -e "$(YELLOW)🧹 Starting fresh...$(NC)"
	@$(MAKE) clean
	@$(MAKE) init
	@echo -e ""
	@echo -e "$(YELLOW)Ready to start services!$(NC)"
	@echo -e "Run: make run-all"

setup:  ## Setup virtual environment and install dependencies
	@if [ ! -d "venv" ] || [ "$(BACKEND_DIR)/requirements.txt" -nt "venv/.deps-installed" ] || [ "$(BACKEND_DIR)/requirements-dev.txt" -nt "venv/.deps-installed" ]; then \
		echo -e "$(YELLOW)Setting up Python environment...$(NC)"; \
		python3 -m venv venv; \
		./venv/bin/pip install --upgrade pip; \
		echo -e "$(YELLOW)Installing production dependencies...$(NC)"; \
		./venv/bin/pip install -r $(BACKEND_DIR)/requirements.txt; \
		echo -e "$(YELLOW)Installing development dependencies...$(NC)"; \
		./venv/bin/pip install -r $(BACKEND_DIR)/requirements-dev.txt; \
		touch venv/.deps-installed; \
		echo -e "$(GREEN)✅ Dependencies installed successfully$(NC)"; \
	else \
		echo -e "$(GREEN)✅ Dependencies already installed and up-to-date$(NC)"; \
	fi

ensure-env-files:  ## Ensure all required env files exist
	@$(MAKE) ensure-backend-env
	@$(MAKE) ensure-frontend-env

ensure-backend-env:  ## Ensure backend .env file exists
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo -e "$(GREEN)✅ Created .env from example$(NC)"; \
	fi

ensure-frontend-env:  ## Ensure frontend .env.local file exists
	@if [ ! -f $(FRONTEND_DIR)/.env.local ]; then \
		cp $(FRONTEND_DIR)/.env.local.example $(FRONTEND_DIR)/.env.local; \
		$(SED_INPLACE) 's/your-secret-api-key-here/test-api-key-123/g' $(FRONTEND_DIR)/.env.local; \
		echo -e "$(GREEN)✅ Created frontend .env.local with default API key$(NC)"; \
	fi

run:  ## Start the backend server (alias for run-backend)
	./backend/setup_and_run.sh

run-backend:  ## Start backend API server
	@echo -e "Starting backend API on port $(API_PORT)..."
	cd $(BACKEND_DIR) && ./setup_and_run.sh

run-frontend:  ## Start frontend dev server
	@echo -e "Starting frontend dev server on port $(FRONTEND_PORT)..."
	cd $(FRONTEND_DIR) && npm run dev

run-frontend-background:  ## Start frontend dev server in background
	@echo -e "$(YELLOW)Starting frontend dev server in background on port $(FRONTEND_PORT)...$(NC)"
	@cd $(FRONTEND_DIR) && nohup npm run dev > ../../frontend.log 2>&1 & echo $$! > ../../.frontend.pid
	@sleep 2
	@if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
		echo -e "$(GREEN)✅ Frontend started in background (PID: $$(cat .frontend.pid))$(NC)"; \
		echo -e "   View logs with: tail -f frontend.log"; \
		echo -e "   Stop with: make stop-frontend"; \
	else \
		echo -e "$(RED)❌ Failed to start frontend$(NC)"; \
		[ -f frontend.log ] && tail -20 frontend.log; \
		exit 1; \
	fi

stop-frontend:  ## Stop background frontend server
	@if [ -f .frontend.pid ]; then \
		echo -e "$(YELLOW)Stopping frontend server...$(NC)"; \
		kill $$(cat .frontend.pid) 2>/dev/null || true; \
		rm -f .frontend.pid; \
		echo -e "$(GREEN)✅ Frontend stopped$(NC)"; \
	else \
		echo -e "$(YELLOW)Frontend is not running in background$(NC)"; \
	fi

check-ollama:  ## Check if Ollama is running and available
	@echo -e "$(YELLOW)Checking Ollama status...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
			echo -e "$(GREEN)✅ Ollama is running$(NC)"; \
			echo -e "   Models available:"; \
			curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | sed 's/^/   - /' || echo "   (unable to list models)"; \
			if ! curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | grep -q "$(GENERATIVE_MODEL)"; then \
				echo -e "$(YELLOW)⚠️  Model $(GENERATIVE_MODEL) not found$(NC)"; \
				echo -e "   Run: ollama pull $(GENERATIVE_MODEL)"; \
			fi; \
			if ! curl -s http://0.0.0.0:11434/api/tags >/dev/null 2>&1; then \
				echo -e "$(YELLOW)⚠️  WARNING: Ollama is only listening on localhost$(NC)"; \
				echo -e "   Docker containers cannot reach it!"; \
				echo -e "   Restart Ollama with: OLLAMA_HOST=0.0.0.0:11434 ollama serve"; \
			fi; \
		else \
			echo -e "$(YELLOW)⚠️  Ollama is installed but not running$(NC)"; \
			echo -e "   Run with proper binding for Docker:"; \
			echo -e "   $(YELLOW)OLLAMA_HOST=0.0.0.0:11434 ollama serve$(NC)"; \
			echo -e "   "; \
			echo -e "   Or configure systemd (Linux):"; \
			echo -e "   sudo mkdir -p /etc/systemd/system/ollama.service.d"; \
			echo -e "   echo '[Service]' | sudo tee /etc/systemd/system/ollama.service.d/override.conf"; \
			echo -e "   echo 'Environment=\"OLLAMA_HOST=0.0.0.0:11434\"' | sudo tee -a /etc/systemd/system/ollama.service.d/override.conf"; \
			echo -e "   sudo systemctl daemon-reload && sudo systemctl restart ollama"; \
		fi \
	else \
		echo -e "$(RED)❌ Ollama is not installed$(NC)"; \
		echo -e "   Visit https://ollama.ai for installation instructions"; \
	fi

check-requirements:  ## Verify all required tools are installed (fails if missing)
	@echo -e "$(YELLOW)Verifying required tools...$(NC)"
	@command -v python3 >/dev/null 2>&1 || { echo -e "$(RED)❌ Python3 is required but not installed.$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ Python3 found$(NC)"
	@command -v npm >/dev/null 2>&1 || { echo -e "$(RED)❌ npm is required but not installed.$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ npm found$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo -e "$(RED)❌ Docker is required but not installed.$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ Docker found$(NC)"
	@command -v docker compose version >/dev/null 2>&1 || { echo -e "$(RED)❌ Docker Compose is required but not installed.$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ Docker Compose found$(NC)"
	@command -v curl >/dev/null 2>&1 || { echo -e "$(RED)❌ curl is required but not installed.$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ curl found$(NC)"
	@command -v jq >/dev/null 2>&1 || { echo -e "$(YELLOW)⚠️  jq is recommended but not installed (some features may not work).$(NC)"; }
	@echo -e "$(GREEN)✅ All required tools are installed!$(NC)"

check-deps:  ## Check all dependencies and services
	@echo -e "$(YELLOW)Checking system dependencies...$(NC)"
	@echo -e -n "Docker: "; \
	if command -v docker >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ $(shell docker --version)$(NC)"; \
	else \
		echo -e "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -e -n "Docker Compose: "; \
	if command -v docker compose >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ $(shell docker compose version)$(NC)"; \
	else \
		echo -e "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -e -n "Python: "; \
	if command -v python3 >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ $(shell python3 --version)$(NC)"; \
	else \
		echo -e "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -e -n "Node.js: "; \
	if command -v node >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ $(shell node --version)$(NC)"; \
	else \
		echo -e "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -e -n "npm: "; \
	if command -v npm >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ $(shell npm --version)$(NC)"; \
	else \
		echo -e "$(RED)❌ Not installed$(NC)"; \
	fi

check-all:  ## Run all checks (ports, deps, ollama)
	@$(MAKE) check-deps
	@echo -e ""
	@$(MAKE) check-ports
	@echo -e ""
	@$(MAKE) check-ollama

status:  ## Show status of all services
	@echo -e "$(YELLOW)Service Status:$(NC)"
	@echo -e "Frontend (http://localhost:$(FRONTEND_PORT)):"
	@if curl -s http://localhost:$(FRONTEND_PORT) >/dev/null 2>&1; then \
		echo -e "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo -e "Backend API (http://localhost:$(API_PORT)):"
	@if curl -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; then \
		echo -e "  $(GREEN)✅ Running$(NC)"; \
		curl -s http://localhost:$(API_PORT)/health | jq -r '.status' | sed 's/^/  Status: /' 2>/dev/null || true; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo -e "ChromaDB (http://localhost:$(CHROMA_GATEWAY_PORT)):"
	@if curl -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1/heartbeat >/dev/null 2>&1; then \
		echo -e "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo -e "Ollama (http://localhost:11434):"
	@if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
		echo -e "  $(GREEN)✅ Running$(NC)"; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo -e ""
	@echo -e "Docker containers:"
	@docker compose ps

run-all:  ## Start all services (docker + frontend) - works from fresh clone
	@echo -e "$(YELLOW)Preparing environment...$(NC)"
	@$(MAKE) ensure-env-files
	@if [ ! -d $(FRONTEND_DIR)/node_modules ]; then \
		echo -e "$(YELLOW)Installing frontend dependencies...$(NC)"; \
		cd $(FRONTEND_DIR) && npm install; \
		echo -e "$(GREEN)✅ Frontend dependencies installed$(NC)"; \
	fi
	@if [ ! -d $(BACKEND_DIR)/venv ]; then \
		echo -e "$(YELLOW)Setting up Python virtual environment...$(NC)"; \
		$(MAKE) setup; \
		echo -e "$(GREEN)✅ Backend dependencies installed$(NC)"; \
	fi
	@$(MAKE) check-ports
	@$(MAKE) check-ollama
	@echo -e "$(YELLOW)Starting all services...$(NC)"
	docker compose up -d
	@echo -e ""
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo -e ""
	@$(MAKE) health-check
	@echo -e ""
	@echo -e "$(YELLOW)Starting frontend...$(NC)"
	cd $(FRONTEND_DIR) && npm run dev

run-all-detached:  ## Start all services in background (non-blocking)
	@$(MAKE) check-requirements
	@echo -e "$(YELLOW)Preparing environment...$(NC)"
	@$(MAKE) ensure-env-files
	@if [ ! -d $(FRONTEND_DIR)/node_modules ]; then \
		echo -e "$(YELLOW)Installing frontend dependencies...$(NC)"; \
		cd $(FRONTEND_DIR) && npm install; \
		echo -e "$(GREEN)✅ Frontend dependencies installed$(NC)"; \
	fi
	@if [ ! -d $(BACKEND_DIR)/venv ]; then \
		echo -e "$(YELLOW)Setting up Python virtual environment...$(NC)"; \
		$(MAKE) setup; \
		echo -e "$(GREEN)✅ Backend dependencies installed$(NC)"; \
	fi
	@$(MAKE) check-ports
	@$(MAKE) check-ollama
	@echo -e "$(YELLOW)Starting all services...$(NC)"
	docker compose up -d
	@echo -e ""
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo -e ""
	@$(MAKE) health-check
	@echo -e ""
	@$(MAKE) run-frontend-background
	@echo -e ""
	@echo -e "$(GREEN)✅ All services are running!$(NC)"
	@echo -e ""
	@echo -e "Access points:"
	@echo -e "  - Frontend: http://localhost:$(FRONTEND_PORT)"
	@echo -e "  - Backend API: http://localhost:$(API_PORT)"
	@echo -e "  - API Docs: http://localhost:$(API_PORT)/docs"
	@echo -e ""
	@echo -e "Useful commands:"
	@echo -e "  - View all logs: make logs"
	@echo -e "  - View frontend logs: tail -f frontend.log"
	@echo -e "  - Stop all services: make stop-all"
	@echo -e "  - Check status: make status"

dev:  ## Start development environment (alias for run-all-detached)
	@$(MAKE) run-all-detached

run-debug:  ## Start services with debug profile (includes netshoot container)
	@echo -e "$(YELLOW)Starting services with debug profile...$(NC)"
	@$(MAKE) ensure-env-files
	@$(MAKE) check-ports
	docker compose --profile debug up -d
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo -e "$(GREEN)✅ Debug environment ready$(NC)"
	@echo -e "Debug container: docker compose exec debug sh"

run-prod:  ## Start services with production profile
	@echo -e "$(YELLOW)Starting services with production profile...$(NC)"
	@if [ -f .env.production ]; then \
		echo -e "$(GREEN)Using .env.production$(NC)"; \
		cp .env .env.backup 2>/dev/null || true; \
		cp .env.production .env; \
	else \
		echo -e "$(YELLOW)⚠️  No .env.production found, using default .env$(NC)"; \
		echo -e "   Create from: cp .env.production.example .env.production"; \
	fi
	@$(MAKE) ensure-env-files
	@$(MAKE) check-ports
	@$(MAKE) security-check
	docker compose --profile production up -d
	@$(MAKE) wait-for-chromadb
	@$(MAKE) wait-for-backend
	@echo -e "$(GREEN)✅ Production environment ready$(NC)"

run-all-with-ollama:  ## Start all services including Ollama
	@$(MAKE) check-ports
	@if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
		echo -e "$(YELLOW)Starting Ollama in background with Docker-compatible binding...$(NC)"; \
		OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve > ollama.log 2>&1 & \
		echo $$! > .ollama.pid; \
		sleep 3; \
		echo -e "$(GREEN)✅ Ollama started on 0.0.0.0:11434$(NC)"; \
	else \
		if ! curl -s http://0.0.0.0:11434/api/tags >/dev/null 2>&1; then \
			echo -e "$(YELLOW)⚠️  Ollama is running but only on localhost$(NC)"; \
			echo -e "   Please restart with: OLLAMA_HOST=0.0.0.0:11434 ollama serve"; \
		fi; \
	fi
	@$(MAKE) run-all

rebuild-all:  ## Rebuild all Docker images (no cache) and start services
	@echo -e "$(YELLOW)Rebuilding all services...$(NC)"
	docker compose down
	docker compose build --no-cache
	@$(MAKE) run-all

build-with-cache:  ## Build images with cache optimization
	@echo -e "$(YELLOW)Building with cache optimization...$(NC)"
	@mkdir -p /tmp/.buildx-cache
	DOCKER_BUILDKIT=1 docker compose build
	@echo -e "$(GREEN)✅ Build complete with cache$(NC)"

dev-setup:  ## Complete development environment setup
	@echo -e "$(YELLOW)Setting up development environment...$(NC)"
	@$(MAKE) check-deps
	@echo -e ""
	@echo -e "$(YELLOW)Installing backend dependencies...$(NC)"
	@$(MAKE) setup
	@echo -e ""
	@echo -e "$(YELLOW)Installing frontend dependencies...$(NC)"
	@cd $(FRONTEND_DIR) && npm install
	@echo -e ""
	@echo -e "$(GREEN)✅ Development environment ready!$(NC)"
	@echo -e "Run 'make run-all' to start all services"

test:  ## Run backend tests
	./backend/run_tests.sh

test-all:  ## Run all tests (backend + frontend)
	@echo -e "Running backend tests..."
	cd backend && ./run_tests.sh
	@echo -e "Running frontend linting..."
	cd $(FRONTEND_DIR) && npm run lint

lint:  ## Run code linting
	./venv/bin/ruff check backend/
	./venv/bin/black --check backend/

validate-setup:  ## Validate the entire setup configuration
	@echo -e "$(YELLOW)Validating setup...$(NC)"
	@echo -e -n "Checking .env file: "
	@if [ -f .env ]; then \
		echo -e "$(GREEN)✅ Found$(NC)"; \
	else \
		echo -e "$(RED)❌ Missing$(NC)"; \
		exit 1; \
	fi
	@echo -e -n "Checking backend Dockerfile: "
	@if grep -q "COPY --chown=appuser:appuser \*.py \./" $(BACKEND_DIR)/Dockerfile 2>/dev/null; then \
		echo -e "$(GREEN)✅ Correct$(NC)"; \
	else \
		echo -e "$(RED)❌ Needs fix (wrong COPY path)$(NC)"; \
		echo -e "   Run: make fix-dockerfile"; \
	fi
	@echo -e -n "Checking Docker images: "
	@if docker images | grep -q synapse-backend; then \
		echo -e "$(GREEN)✅ Built$(NC)"; \
		echo -e "   Built: $$(docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}' | grep synapse-backend | head -1)"; \
	else \
		echo -e "$(YELLOW)⚠️  Not built$(NC)"; \
	fi
	@echo -e -n "Checking required models: "
	@if curl -s http://localhost:11434/api/tags 2>/dev/null | jq -r '.models[].name' | grep -q "$(GENERATIVE_MODEL)"; then \
		echo -e "$(GREEN)✅ $(GENERATIVE_MODEL) available$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  $(GENERATIVE_MODEL) not pulled$(NC)"; \
	fi

health-check:  ## Check health of all running services
	@echo -e "$(YELLOW)Checking service health...$(NC)"
	@echo -e -n "Backend API: "
	@if curl -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; then \
		health=$$(curl -s http://localhost:$(API_PORT)/health | jq -r '.status' 2>/dev/null); \
		if [ "$$health" = "healthy" ]; then \
			echo -e "$(GREEN)✅ Healthy$(NC)"; \
		elif [ "$$health" = "degraded" ]; then \
			echo -e "$(YELLOW)⚠️  Degraded$(NC)"; \
			curl -s http://localhost:$(API_PORT)/health | jq '.dependencies' 2>/dev/null | sed 's/^/  /' || true; \
		else \
			echo -e "$(RED)❌ Unhealthy$(NC)"; \
		fi \
	else \
		echo -e "$(RED)❌ Not responding$(NC)"; \
	fi
	@echo -e -n "ChromaDB: "
	@if curl -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1/heartbeat >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ Healthy$(NC)"; \
	else \
		echo -e "$(RED)❌ Not responding$(NC)"; \
	fi

docker-shell:  ## Open a shell in the backend container
	@echo -e "$(YELLOW)Opening shell in backend container...$(NC)"
	docker compose exec backend /bin/bash

pull-models:  ## Pull required Ollama models
	@echo -e "$(YELLOW)Pulling required models...$(NC)"
	@if command -v ollama >/dev/null 2>&1; then \
		echo -e "Pulling $(GENERATIVE_MODEL)..."; \
		ollama pull $(GENERATIVE_MODEL); \
		echo -e "Pulling mxbai-embed-large..."; \
		ollama pull mxbai-embed-large; \
		echo -e "$(GREEN)✅ Models pulled successfully$(NC)"; \
	else \
		echo -e "$(RED)❌ Ollama not installed$(NC)"; \
	fi

start-ollama:  ## Start Ollama with Docker-compatible binding
	@echo -e "$(YELLOW)Starting Ollama with Docker-compatible binding...$(NC)"
	@if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then \
		if ! curl -s http://0.0.0.0:11434/api/tags >/dev/null 2>&1; then \
			echo -e "$(YELLOW)⚠️  Ollama is already running on localhost only$(NC)"; \
			echo -e "   Please stop it first and run: make start-ollama"; \
		else \
			echo -e "$(GREEN)✅ Ollama is already running with correct binding$(NC)"; \
		fi; \
	else \
		echo -e "Starting Ollama on 0.0.0.0:11434..."; \
		OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve > ollama.log 2>&1 & \
		echo $$! > .ollama.pid; \
		sleep 3; \
		if curl -s http://0.0.0.0:11434/api/tags >/dev/null 2>&1; then \
			echo -e "$(GREEN)✅ Ollama started successfully on 0.0.0.0:11434$(NC)"; \
			echo -e "   PID: $$(cat .ollama.pid)"; \
			echo -e "   Logs: tail -f ollama.log"; \
		else \
			echo -e "$(RED)❌ Failed to start Ollama$(NC)"; \
			[ -f ollama.log ] && tail -20 ollama.log; \
		fi; \
	fi

fix-dockerfile:  ## Fix the Dockerfile COPY path issue
	@echo -e "$(YELLOW)Fixing Dockerfile...$(NC)"
	@cp $(BACKEND_DIR)/Dockerfile $(BACKEND_DIR)/Dockerfile.bak
	@$(SED_INPLACE) 's/COPY --chown=appuser:appuser \*.py backend\//COPY --chown=appuser:appuser *.py .\//g' $(BACKEND_DIR)/Dockerfile
	@echo -e "$(GREEN)✅ Dockerfile fixed$(NC)"
	@echo -e "   Backup saved to $(BACKEND_DIR)/Dockerfile.bak"
	@echo -e "   Run 'make rebuild-all' to rebuild with the fix"

wait-for-backend:  ## Wait for backend to be healthy
	@echo -e "$(YELLOW)Waiting for backend to be healthy...$(NC)"
	@timeout=30; \
	start_time=$$SECONDS; \
	while ! curl -f -s http://localhost:$(API_PORT)/health >/dev/null 2>&1; do \
		elapsed=$$((SECONDS - start_time)); \
		if [ $$elapsed -ge $$timeout ]; then \
			echo -e ""; \
			echo -e "$(RED)❌ Backend failed to become healthy after $$timeout seconds$(NC)"; \
			echo -e "Check logs with: make logs-backend"; \
			exit 1; \
		fi; \
		echo -e -n "."; \
		sleep 1; \
	done; \
	echo -e ""; \
	echo -e "$(GREEN)✅ Backend is healthy!$(NC)"

wait-for-chromadb:  ## Wait for ChromaDB to be ready
	@echo -e "$(YELLOW)Waiting for ChromaDB to be ready...$(NC)"
	@timeout=30; \
	start_time=$$SECONDS; \
	while ! curl -f -s http://localhost:$(CHROMA_GATEWAY_PORT)/api/v1 >/dev/null 2>&1; do \
		elapsed=$$((SECONDS - start_time)); \
		if [ $$elapsed -ge $$timeout ]; then \
			echo -e ""; \
			echo -e "$(RED)❌ ChromaDB failed to become ready after $$timeout seconds$(NC)"; \
			echo -e "Check logs with: make logs-chromadb"; \
			exit 1; \
		fi; \
		echo -e -n "."; \
		sleep 1; \
	done; \
	echo -e ""; \
	echo -e "$(GREEN)✅ ChromaDB is ready!$(NC)"

stop-all:  ## Stop all docker services
	@echo -e "$(YELLOW)Stopping all services...$(NC)"
	docker compose down
	@if [ -f .frontend.pid ]; then \
		echo -e "Stopping frontend..."; \
		kill $$(cat .frontend.pid) 2>/dev/null || true; \
		rm -f .frontend.pid; \
	fi
	@if [ -f .ollama.pid ]; then \
		echo -e "Stopping Ollama..."; \
		kill $$(cat .ollama.pid) 2>/dev/null || true; \
		rm -f .ollama.pid; \
	fi
	@echo -e "$(GREEN)✅ All services stopped$(NC)"

logs:  ## View docker logs
	docker compose logs -f

check-ports:  ## Check if required ports are available
	@echo -e "Checking port availability..."
	@for port in $(FRONTEND_PORT) $(API_PORT) $(CHROMA_GATEWAY_PORT); do \
		if lsof -i :$$port >/dev/null 2>&1; then \
			echo -e "⚠️  Port $$port is already in use!"; \
			lsof -i :$$port | grep LISTEN; \
		else \
			echo -e "✅ Port $$port is available"; \
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
		echo -e "$(YELLOW)No Ollama log file found. Ollama may be running as a system service.$(NC)"; \
		echo -e "Try: journalctl -u ollama -f"; \
	fi

restart:  ## Restart specific service (usage: make restart service=backend)
	@if [ -z "$(service)" ]; then \
		echo -e "$(RED)Error: Please specify a service$(NC)"; \
		echo -e "Usage: make restart service=backend"; \
		echo -e "Available services: backend, chromadb"; \
	else \
		echo -e "$(YELLOW)Restarting $(service)...$(NC)"; \
		docker compose restart $(service); \
		echo -e "$(GREEN)✅ $(service) restarted$(NC)"; \
	fi

ingest-test:  ## Test document ingestion
	@echo -e "$(YELLOW)Testing document ingestion...$(NC)"
	@curl -X POST http://localhost:$(API_PORT)/api/documents \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: test-api-key-123" \
		-d '{"title": "Test Document", "content": "This is a test document for ingestion.", "source": "test"}' \
		2>/dev/null | jq . || echo -e "$(RED)❌ Ingestion failed$(NC)"

query-test:  ## Test RAG query
	@echo -e "$(YELLOW)Testing RAG query...$(NC)"
	@curl -X POST http://localhost:$(API_PORT)/api/chat \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: test-api-key-123" \
		-d '{"message": "What is a test document?", "max_context_documents": 5}' \
		2>/dev/null | jq . || echo -e "$(RED)❌ Query failed$(NC)"

backup-data:  ## Backup SQLite database and ChromaDB data
	@echo -e "$(YELLOW)Backing up data...$(NC)"
	@BACKUP_DIR="backups/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$BACKUP_DIR"; \
	if [ -f "$(BACKEND_DIR)/capture.db" ]; then \
		cp "$(BACKEND_DIR)/capture.db" "$$BACKUP_DIR/"; \
		echo -e "$(GREEN)✅ SQLite database backed up$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  No SQLite database found$(NC)"; \
	fi; \
	if [ -d chromadb_data ]; then \
		cp -r chromadb_data "$$BACKUP_DIR/"; \
		echo -e "$(GREEN)✅ ChromaDB data backed up$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  No ChromaDB data found$(NC)"; \
	fi; \
	echo -e "$(GREEN)Backup saved to: $$BACKUP_DIR/$(NC)"

restore-data:  ## Restore SQLite database and ChromaDB data from backup
	@echo -e "$(YELLOW)Available backups:$(NC)"
	@if [ -d backups ]; then \
		ls -1dt backups/*/ 2>/dev/null | head -10 | nl -v 1 || echo -e "$(RED)No backups found$(NC)"; \
	else \
		echo -e "$(RED)No backups directory found$(NC)"; \
		exit 1; \
	fi
	@echo -e ""
	@read -p "Enter backup number to restore (or full path): " backup_choice; \
	if [ -z "$$backup_choice" ]; then \
		echo -e "$(RED)❌ No backup selected$(NC)"; \
		exit 1; \
	fi; \
	if [ -d "$$backup_choice" ]; then \
		BACKUP_PATH="$$backup_choice"; \
	else \
		BACKUP_PATH=$$(ls -1dt backups/*/ 2>/dev/null | sed -n "$${backup_choice}p"); \
	fi; \
	if [ -z "$$BACKUP_PATH" ] || [ ! -d "$$BACKUP_PATH" ]; then \
		echo -e "$(RED)❌ Invalid backup selection$(NC)"; \
		exit 1; \
	fi; \
	echo -e "$(YELLOW)Restoring from: $$BACKUP_PATH$(NC)"; \
	echo -e "$(RED)WARNING: This will overwrite existing data!$(NC)"; \
	read -p "Continue? (y/N): " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo -e "$(YELLOW)Restore cancelled$(NC)"; \
		exit 0; \
	fi; \
	if [ -f "$$BACKUP_PATH/capture.db" ]; then \
		cp "$$BACKUP_PATH/capture.db" $(BACKEND_DIR)/capture.db; \
		echo -e "$(GREEN)✅ SQLite database restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  No SQLite database in backup$(NC)"; \
	fi; \
	if [ -d "$$BACKUP_PATH/chromadb_data" ]; then \
		rm -rf chromadb_data; \
		cp -r "$$BACKUP_PATH/chromadb_data" chromadb_data; \
		echo -e "$(GREEN)✅ ChromaDB data restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  No ChromaDB data in backup$(NC)"; \
	fi; \
	echo -e "$(GREEN)✅ Restore complete from: $$BACKUP_PATH$(NC)"; \
	echo -e "$(YELLOW)Note: Restart services with 'make stop-all && make dev' to use restored data$(NC)"

monitor:  ## Live monitoring dashboard (requires watch command)
	@if command -v watch >/dev/null 2>&1; then \
		watch -n 2 -c "make status"; \
	else \
		echo -e "$(RED)❌ 'watch' command not found$(NC)"; \
		echo -e "Install with: sudo apt-get install watch (Linux) or brew install watch (macOS)"; \
	fi

docs:  ## Show comprehensive documentation
	@echo -e "$(YELLOW)📚 Capture-v3 Makefile Documentation$(NC)"
	@echo -e ""
	@echo -e "$(GREEN)=== Quick Start ===$(NC)"
	@echo -e "For new users, run these commands in order:"
	@echo -e "  1. $(YELLOW)make init$(NC)         - Initialize project from fresh clone"
	@echo -e "  2. $(YELLOW)make dev$(NC)          - Start all services in background"
	@echo -e "  3. $(YELLOW)make status$(NC)       - Check if everything is running"
	@echo -e ""
	@echo -e "$(GREEN)=== Common Workflows ===$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Development:$(NC)"
	@echo -e "  make dev             - Start all services in background (recommended)"
	@echo -e "  make stop-all        - Stop all services"
	@echo -e "  make logs            - View all logs"
	@echo -e "  make status          - Check service health"
	@echo -e ""
	@echo -e "$(YELLOW)Troubleshooting:$(NC)"
	@echo -e "  make troubleshoot    - Interactive troubleshooting guide"
	@echo -e "  make check-deps      - Verify all dependencies"
	@echo -e "  make check-ports     - Check if ports are available"
	@echo -e "  make health-check    - Detailed health status"
	@echo -e ""
	@echo -e "$(YELLOW)Data Management:$(NC)"
	@echo -e "  make backup-data     - Backup SQLite and ChromaDB data"
	@echo -e "  make restore-data    - Restore from backup"
	@echo -e ""
	@echo -e "$(GREEN)=== Service Ports ===$(NC)"
	@echo -e "  Frontend:     http://localhost:$(FRONTEND_PORT)"
	@echo -e "  Backend API:  http://localhost:$(API_PORT)"
	@echo -e "  API Docs:     http://localhost:$(API_PORT)/docs"
	@echo -e "  ChromaDB:     http://localhost:$(CHROMA_GATEWAY_PORT)"
	@echo -e ""
	@echo -e "$(GREEN)=== Environment Files ===$(NC)"
	@echo -e "  Root .env:                    Main configuration (ports, API keys)"
	@echo -e "  $(FRONTEND_DIR)/.env.local:    Frontend config (backend URL, API key)"
	@echo -e "  $(BACKEND_DIR)/.env.development:  Backend config (models, DB paths)"
	@echo -e ""
	@echo -e "$(GREEN)=== Docker Services ===$(NC)"
	@echo -e "  backend:  FastAPI application with Haystack RAG"
	@echo -e "  chromadb: Vector database for embeddings"
	@echo -e ""
	@echo -e "$(GREEN)=== Advanced Features ===$(NC)"
	@echo -e "  make rebuild-all     - Force rebuild all Docker images"
	@echo -e "  make docker-shell    - Open shell in backend container"
	@echo -e "  make pull-models     - Download Ollama models"
	@echo -e "  make monitor         - Live monitoring dashboard"
	@echo -e ""
	@echo -e "For all available commands: $(YELLOW)make help$(NC)"

security-check:  ## Run security checks and recommendations
	@echo -e "$(YELLOW)🔒 Security Check$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Checking environment files...$(NC)"
	@if [ -f .env ] && grep -q "your-secret-api-key-here\|test-api-key-123" .env; then \
		echo -e "$(RED)⚠️  WARNING: Default API key detected in .env$(NC)"; \
		echo -e "   Generate secure key: openssl rand -hex 32"; \
	else \
		echo -e "$(GREEN)✅ No default API keys in .env$(NC)"; \
	fi
	@if [ -f $(FRONTEND_DIR)/.env.local ] && grep -q "your-secret-api-key-here\|test-api-key-123" $(FRONTEND_DIR)/.env.local; then \
		echo -e "$(RED)⚠️  WARNING: Default API key in frontend .env.local$(NC)"; \
	else \
		echo -e "$(GREEN)✅ No default API keys in frontend config$(NC)"; \
	fi
	@echo -e ""
	@echo -e "$(YELLOW)Checking ChromaDB settings...$(NC)"
	@if [ -f .env ] && grep -q "CHROMADB_ALLOW_RESET=TRUE" .env; then \
		echo -e "$(YELLOW)⚠️  ChromaDB ALLOW_RESET is TRUE$(NC)"; \
		echo -e "   Set to FALSE for production environments"; \
	else \
		echo -e "$(GREEN)✅ ChromaDB ALLOW_RESET is secure$(NC)"; \
	fi
	@echo -e ""
	@echo -e "$(YELLOW)Checking Git security...$(NC)"
	@if git ls-files --error-unmatch .env >/dev/null 2>&1; then \
		echo -e "$(RED)⚠️  WARNING: .env is tracked in Git!$(NC)"; \
		echo -e "   Run: git rm --cached .env"; \
	else \
		echo -e "$(GREEN)✅ .env is not tracked in Git$(NC)"; \
	fi
	@if git ls-files --error-unmatch $(FRONTEND_DIR)/.env.local >/dev/null 2>&1; then \
		echo -e "$(RED)⚠️  WARNING: frontend .env.local is tracked in Git!$(NC)"; \
	else \
		echo -e "$(GREEN)✅ Frontend .env.local is not tracked$(NC)"; \
	fi
	@echo -e ""
	@echo -e "$(YELLOW)Recommendations:$(NC)"
	@echo -e "  1. Use environment-specific .env files (.env.production)"
	@echo -e "  2. Rotate API keys regularly"
	@echo -e "  3. Use Docker secrets for sensitive data in production"
	@echo -e "  4. Enable HTTPS for production deployments"
	@echo -e "  5. Review docker-compose resource limits"
	@echo -e ""
	@echo -e "$(GREEN)Security check complete$(NC)"

debug-env:  ## Show all environment variables
	@echo -e "$(YELLOW)Environment Configuration:$(NC)"
	@echo -e "Frontend Port: $(FRONTEND_PORT)"
	@echo -e "API Port: $(API_PORT)"
	@echo -e "ChromaDB Port: $(CHROMA_GATEWAY_PORT)"
	@echo -e "API Container Port: $(API_CONTAINER_PORT)"
	@echo -e "Generative Model: $(GENERATIVE_MODEL)"
	@echo -e ""
	@echo -e "$(YELLOW)Backend Environment:$(NC)"
	@cat backend/.env.development | grep -v '^#' | grep -v '^$$' | sed 's/^/  /'

troubleshoot:  ## Interactive troubleshooting guide
	@echo -e "$(YELLOW)Troubleshooting Guide$(NC)"
	@echo -e ""
	@echo -e "1. If backend won't start:"
	@echo -e "   - Check Dockerfile: make validate-setup"
	@echo -e "   - Fix if needed: make fix-dockerfile"
	@echo -e "   - Rebuild: make rebuild-all"
	@echo -e ""
	@echo -e "2. If imports fail:"
	@echo -e "   - Shell into container: make docker-shell"
	@echo -e "   - Check files: ls -la /app/"
	@echo -e "   - Test imports: python -c 'import main'"
	@echo -e ""
	@echo -e "3. If Ollama issues:"
	@echo -e "   - Check status: make check-ollama"
	@echo -e "   - Pull models: make pull-models"
	@echo -e "   - Start with app: make run-all-with-ollama"
	@echo -e ""
	@echo -e "4. View logs:"
	@echo -e "   - All: make logs"
	@echo -e "   - Backend only: make logs-backend"
	@echo -e "   - ChromaDB only: make logs-chromadb"
	@echo -e ""
	@echo -e "Run 'make status' to see current system state"

clean:  ## Clean cache and temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true
	rm -f .ollama.pid ollama.log .frontend.pid frontend.log venv/.deps-installed
	@echo -e "$(GREEN)✅ Cleaned temporary files$(NC)"

reset-chromadb:  ## Reset ChromaDB by cleaning volumes and rebuilding (fixes startup issues)
	@echo -e "$(YELLOW)🔧 Resetting ChromaDB...$(NC)"
	@./fix-chromadb-startup.sh

clean-docker:  ## Remove Docker images and volumes (CAUTION: deletes data)
	@echo -e "$(RED)WARNING: This will delete all data!$(NC)"
	@echo -e "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	docker compose down -v --rmi all
	@echo -e "$(GREEN)✅ Docker cleanup complete$(NC)"

coffee:  ## Essential developer fuel ☕
	@echo -e "$(YELLOW)    ( ("
	@echo -e "     ) )"
	@echo -e "  ........."
	@echo -e "  |       |]"
	@echo -e "  \       /"
	@echo -e "   \`-----'$(NC)"
	@echo -e ""
	@echo -e "☕ Brewing virtual coffee..."
	@sleep 2
	@echo -e "$(GREEN)✅ Coffee ready! Now get back to coding!$(NC)"
	@echo -e ""
	@echo -e "Fun fact: This codebase was built on approximately 127 cups of coffee."
	@echo -e "Your contribution will increase this counter."