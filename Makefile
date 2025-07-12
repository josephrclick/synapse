# ========================================================================
# Synapse Makefile - Container-First Build System
# ========================================================================
# A streamlined build system for the Synapse knowledge management system
# focusing on Docker Compose orchestration and developer experience.
#
# Quick Start:
#   make init    # First time setup
#   make dev     # Start all services (detached)
#   make help    # Show all commands
#
# Requirements:
# - Docker & Docker Compose v2
# - Python 3.11+ (for backend development)
# - Node.js 18+ (for frontend development)
# ========================================================================

# Shell configuration
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

# Load environment variables
-include .env
export

# Default values
FRONTEND_PORT ?= 8100
API_PORT ?= 8101
CHROMA_GATEWAY_PORT ?= 8102
FRONTEND_DIR ?= frontend/synapse
BACKEND_DIR ?= backend

# Flag to control frontend startup
SKIP_FRONTEND ?= false

# Verbose mode
VERBOSE ?= false
ifeq ($(VERBOSE),true)
	VERBOSE_FLAG := -v
	DOCKER_COMPOSE_FLAGS := --verbose
else
	VERBOSE_FLAG :=
	DOCKER_COMPOSE_FLAGS :=
endif

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m

# List of required ports
REQUIRED_PORTS := $(FRONTEND_PORT) $(API_PORT) $(CHROMA_GATEWAY_PORT) 11434

# Default target
.DEFAULT_GOAL := help

# ========================================================================
# HELP & DOCUMENTATION
# ========================================================================

.PHONY: help
help: ## Show this help message
	@echo -e "$(BLUE)Synapse Development Commands$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Quick Start:$(NC)"
	@echo -e "  $(GREEN)init           $(NC) Initialize project (first time setup)"
	@echo -e "  $(GREEN)dev            $(NC) Start all services in background (recommended)"
	@echo -e "  $(GREEN)stop           $(NC) Stop all services"
	@echo -e "  $(GREEN)status         $(NC) Show service status and health"
	@echo -e "  $(GREEN)logs           $(NC) View logs from all services"
	@echo -e ""
	@echo -e "$(YELLOW)Development:$(NC)"
	@echo -e "  $(GREEN)run-backend    $(NC) Run backend locally (for development)"
	@echo -e "  $(GREEN)run-frontend   $(NC) Run frontend locally (for development)"
	@echo -e "  $(GREEN)test           $(NC) Run all tests"
	@echo -e "  $(GREEN)lint           $(NC) Run linters"
	@echo -e "  $(GREEN)clean          $(NC) Clean temporary files and caches"
	@echo -e ""
	@echo -e "$(YELLOW)Management:$(NC)"
	@echo -e "  $(GREEN)health         $(NC) Show detailed health status"
	@echo -e "  $(GREEN)health-detailed$(NC) Show Docker health status for each service"
	@echo -e "  $(GREEN)reset          $(NC) Reset all services and data"
	@echo -e "  $(GREEN)backup         $(NC) Backup data (SQLite + ChromaDB)"
	@echo -e "  $(GREEN)restore        $(NC) Restore from backup"
	@echo -e "  $(GREEN)shell          $(NC) Open shell in backend container"
	@echo -e "  $(GREEN)check-models   $(NC) Check installed Ollama models"
	@echo -e "  $(GREEN)pull-models    $(NC) Pull all required Ollama models"
	@echo -e "  $(GREEN)interactive-pull-models$(NC) Interactive model management"
	@echo -e ""
	@echo -e "$(YELLOW)Troubleshooting:$(NC)"
	@echo -e "  $(GREEN)check-requirements$(NC) Verify required tools are installed"
	@echo -e "  $(GREEN)check-ports    $(NC) Check if required ports are available"
	@echo -e "  $(GREEN)troubleshoot   $(NC) Interactive troubleshooting guide"
	@echo -e "  $(GREEN)logs-backend   $(NC) View backend logs"
	@echo -e "  $(GREEN)logs-chromadb  $(NC) View ChromaDB logs"
	@echo -e "  $(GREEN)logs-ollama    $(NC) View Ollama logs"
	@echo -e "  $(GREEN)kill-frontend  $(NC) Force kill any process on frontend port"
	@echo -e ""
	@echo -e "$(YELLOW)Shortcuts:$(NC)"
	@echo -e "  $(GREEN)rebuild        $(NC) Rebuild containers (no cache)"
	@echo -e "  $(GREEN)restart        $(NC) Restart specific service"
	@echo -e "  $(GREEN)fresh          $(NC) Complete fresh start"
	@echo -e "  $(GREEN)qs             $(NC) Quick status (alias for quick-status)"
	@echo -e ""
	@echo -e "$(YELLOW)Common Workflows:$(NC)"
	@echo -e "  First time:  make init && make dev"
	@echo -e "  Daily:       make dev, make qs, make stop"
	@echo -e "  Debug:       make logs, make troubleshoot"
	@echo -e "  Verbose:     VERBOSE=true make dev"

# ========================================================================
# QUICK START COMMANDS
# ========================================================================

.PHONY: init
init: ## Initialize project (first time setup)
	@echo -e "$(BLUE)🚀 Initializing Synapse...$(NC)"
	@$(MAKE) check-requirements
	@$(MAKE) ensure-env-files
	@echo -e ""
	@echo -e "$(YELLOW)Installing backend dependencies...$(NC)"
	@$(MAKE) setup-backend
	@echo -e ""
	@echo -e "$(YELLOW)Installing frontend dependencies...$(NC)"
	@cd $(FRONTEND_DIR) && npm install
	@echo -e ""
	@echo -e "$(GREEN)✅ Initialization complete!$(NC)"
	@echo -e ""
	@echo -e "Next steps:"
	@echo -e "  1. $(YELLOW)make dev$(NC)    - Start all services"
	@echo -e "  2. $(YELLOW)make status$(NC) - Check service health"
	@echo -e ""
	@echo -e "Access points:"
	@echo -e "  Frontend: http://localhost:$(FRONTEND_PORT)"
	@echo -e "  API Docs: http://localhost:$(API_PORT)/docs"

.PHONY: dev
dev: ## Start all services in background (recommended)
	@$(MAKE) check-ports
	@echo -e "$(YELLOW)Starting all services...$(NC)"
	@docker compose $(DOCKER_COMPOSE_FLAGS) up -d
	@echo -e ""
	@echo -e "$(YELLOW)Waiting for services to be healthy...$(NC)"
	@$(MAKE) wait-for-services
	@echo -e ""
	@# Check for Ollama models after services are healthy
	@echo -e "$(YELLOW)Checking Ollama models...$(NC)"
	@INSTALLED_MODELS=$$(docker compose exec ollama ollama list 2>/dev/null | tail -n +2 | awk '{print $$1}' | sort | uniq || echo ""); \
	REQUIRED_MODELS="gemma3n:e2b mxbai-embed-large:latest linux6200/bge-reranker-v2-m3:latest"; \
	MISSING_MODELS=""; \
	for model in $$REQUIRED_MODELS; do \
		if ! echo "$$INSTALLED_MODELS" | grep -q "^$$model$$"; then \
			MISSING_MODELS="$$MISSING_MODELS $$model"; \
		fi; \
	done; \
	if [ -n "$$MISSING_MODELS" ]; then \
		echo -e "$(YELLOW)⚠️  Missing required Ollama models$(NC)"; \
		echo -e ""; \
		$(MAKE) interactive-pull-models; \
		echo -e ""; \
	else \
		echo -e "$(GREEN)✅ All required models installed$(NC)"; \
	fi
	@$(MAKE) start-frontend-background
	@echo -e ""
	@$(MAKE) show-status
	@echo -e ""
	@echo -e "$(GREEN)✅ Development environment ready!$(NC)"
	@echo -e ""
	@echo -e "Commands:"
	@echo -e "  $(YELLOW)make logs$(NC)   - View all logs"
	@echo -e "  $(YELLOW)make status$(NC) - Check health"
	@echo -e "  $(YELLOW)make stop$(NC)   - Stop everything"

.PHONY: stop
stop: ## Stop all services
	@echo -e "$(YELLOW)Stopping all services...$(NC)"
	@echo -e ""
	@echo -e "$(BLUE)Stopping Docker services...$(NC)"
	@docker compose down
	@echo -e ""
	@echo -e "$(BLUE)Stopping frontend...$(NC)"
	@$(MAKE) stop-frontend --no-print-directory
	@echo -e ""
	@echo -e "$(GREEN)✅ All services stopped$(NC)"

.PHONY: status
status: ## Show service status and health
	@echo -e "$(BLUE)Service Status$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Docker Services:$(NC)"
	@docker compose ps
	@echo -e ""
	@echo -e "$(YELLOW)Frontend:$(NC)"
	@if [ -f .frontend.skip ]; then \
		echo -e "  $(YELLOW)⚠️  Skipped$(NC) (port $(FRONTEND_PORT) was in use)"; \
		echo -e "  To start manually: cd $(FRONTEND_DIR) && npm run dev"; \
	elif ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
			echo -e "  $(GREEN)✅ Running$(NC) (Makefile-managed, PID: $$(cat .frontend.pid))"; \
		else \
			echo -e "  $(GREEN)✅ Running$(NC) (externally managed)"; \
			FRONTEND_PROCESS=$$(ss -tlnp 2>/dev/null | grep ":$(FRONTEND_PORT)\s" | grep -oP 'pid=\K[0-9]+' | head -1 || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN -t 2>/dev/null | head -1); \
			if [ -n "$$FRONTEND_PROCESS" ]; then \
				echo -e "  Process: PID $$FRONTEND_PROCESS"; \
			fi; \
		fi; \
		echo -e "  URL: http://localhost:$(FRONTEND_PORT)"; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi

.PHONY: quick-status qs
quick-status qs: ## Quick service status check (alias: qs)
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}" | grep -E "(NAME|backend|chromadb|ollama)" || echo "No services running"
	@echo -n "Frontend: "; \
	if ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "✅ Running on port $(FRONTEND_PORT)"; \
	else \
		echo "❌ Not running"; \
	fi

.PHONY: logs
logs: ## View logs from all services
	@docker compose logs -f

# ========================================================================
# DEVELOPMENT COMMANDS
# ========================================================================

.PHONY: run-backend
run-backend: ## Run backend locally (for development)
	@echo -e "$(YELLOW)Starting backend in development mode...$(NC)"
	cd $(BACKEND_DIR) && ./setup_and_run.sh

.PHONY: run-frontend
run-frontend: ## Run frontend locally (for development)
	@echo -e "$(YELLOW)Starting frontend in development mode...$(NC)"
	cd $(FRONTEND_DIR) && npm run dev

.PHONY: test
test: ## Run all tests
	@echo -e "$(YELLOW)Running tests...$(NC)"
	@if [ -f ./tests/test-all.sh ]; then \
		./tests/test-all.sh; \
	else \
		echo -e "$(RED)Test script not found$(NC)"; \
	fi

.PHONY: lint
lint: ## Run linters
	@echo -e "$(YELLOW)Running linters...$(NC)"
	@if [ -d venv ]; then \
		./venv/bin/ruff check $(BACKEND_DIR)/; \
		./venv/bin/black --check $(BACKEND_DIR)/; \
	fi
	@cd $(FRONTEND_DIR) && npm run lint

.PHONY: clean
clean: ## Clean temporary files and caches
	@echo -e "$(YELLOW)Cleaning temporary files...$(NC)"
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "node_modules/.cache" -exec rm -rf {} + 2>/dev/null || true
	@rm -f .frontend.pid frontend.log .frontend.skip
	@rm -f ./*.log 2>/dev/null || true
	@# Clean any orphaned Docker resources
	@docker system prune -f --volumes --filter "label!=keep" 2>/dev/null || true
	@echo -e "$(GREEN)✅ Cleaned$(NC)"

# ========================================================================
# MANAGEMENT COMMANDS
# ========================================================================

.PHONY: health
health: ## Show detailed health status
	@$(MAKE) health-detailed --no-print-directory

.PHONY: health-detailed
health-detailed: ## Show detailed Docker health status for each service
	@echo -e "$(BLUE)Docker Health Status$(NC)"
	@echo -e ""
	@docker compose ps
	@echo -e ""
	@echo -e "$(YELLOW)Quick Health Check:$(NC)"
	@ALL_HEALTHY=true; \
	for service in backend chromadb ollama; do \
		if docker compose ps $$service --format json | jq -e '.Health == "healthy"' >/dev/null 2>&1; then \
			echo -e "  $$service: $(GREEN)✅ Healthy$(NC)"; \
		else \
			echo -e "  $$service: $(RED)❌ Not healthy$(NC)"; \
			ALL_HEALTHY=false; \
		fi; \
	done; \
	if [ "$$ALL_HEALTHY" = true ]; then \
		echo -e ""; \
		echo -e "$(GREEN)All services are healthy!$(NC)"; \
	fi
	@echo -e ""
	@echo -e "$(YELLOW)Service URLs:$(NC)"
	@echo -e "  Frontend:    http://localhost:$(FRONTEND_PORT)"
	@echo -e "  Backend API: http://localhost:$(API_PORT)"
	@echo -e "  API Docs:    http://localhost:$(API_PORT)/docs"
	@echo -e "  ChromaDB:    http://localhost:$(CHROMA_GATEWAY_PORT)"
	@echo -e "  Ollama:      http://localhost:11434"

.PHONY: reset
reset: ## Reset all services and data
	@echo -e "$(RED)⚠️  This will delete all data!$(NC)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) stop; \
		docker compose down -v; \
		rm -f $(BACKEND_DIR)/synapse.db*; \
		echo -e "$(GREEN)✅ Reset complete$(NC)"; \
	else \
		echo -e "$(YELLOW)Reset cancelled$(NC)"; \
	fi

.PHONY: backup
backup: ## Backup data (SQLite + ChromaDB)
	@echo -e "$(YELLOW)Creating backup...$(NC)"
	@# Check if ChromaDB is healthy before backup
	@CHROMADB_HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q chromadb 2>/dev/null) 2>/dev/null || echo "not-running"); \
	if [ "$$CHROMADB_HEALTH" != "healthy" ]; then \
		echo -e "$(RED)❌ Cannot backup - ChromaDB is $$CHROMADB_HEALTH$(NC)"; \
		echo -e "Run $(GREEN)make health-detailed$(NC) for more information"; \
		exit 1; \
	fi
	@BACKUP_DIR="backups/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$BACKUP_DIR"; \
	if [ -f "$(BACKEND_DIR)/synapse.db" ]; then \
		cp "$(BACKEND_DIR)/synapse.db" "$$BACKUP_DIR/"; \
		echo -e "$(GREEN)✅ SQLite backed up$(NC)"; \
	fi; \
	docker compose exec chromadb tar -czf - /chroma/chroma > "$$BACKUP_DIR/chromadb.tar.gz" 2>/dev/null && \
		echo -e "$(GREEN)✅ ChromaDB backed up$(NC)" || \
		echo -e "$(YELLOW)⚠️  ChromaDB backup failed$(NC)"; \
	echo -e "Backup saved to: $$BACKUP_DIR"

.PHONY: restore
restore: ## Restore from backup
	@echo -e "$(YELLOW)Available backups:$(NC)"
	@ls -1dt backups/*/ 2>/dev/null | head -10 | nl -v 1 || echo "No backups found"
	@read -p "Enter backup number: " choice; \
	BACKUP_PATH=$$(ls -1dt backups/*/ 2>/dev/null | sed -n "$${choice}p"); \
	if [ -n "$$BACKUP_PATH" ] && [ -d "$$BACKUP_PATH" ]; then \
		echo -e "$(YELLOW)Restoring from $$BACKUP_PATH...$(NC)"; \
		$(MAKE) stop; \
		if [ -f "$$BACKUP_PATH/synapse.db" ]; then \
			cp "$$BACKUP_PATH/synapse.db" $(BACKEND_DIR)/; \
			echo -e "$(GREEN)✅ SQLite restored$(NC)"; \
		fi; \
		if [ -f "$$BACKUP_PATH/chromadb.tar.gz" ]; then \
			docker compose up -d chromadb; \
			echo -e "$(YELLOW)Waiting for ChromaDB to be healthy...$(NC)"; \
			for i in {1..30}; do \
				HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q chromadb 2>/dev/null) 2>/dev/null || echo "not-running"); \
				if [ "$$HEALTH" = "healthy" ]; then \
					break; \
				fi; \
				sleep 2; \
			done; \
			docker compose exec chromadb tar -xzf - -C / < "$$BACKUP_PATH/chromadb.tar.gz" && \
			echo -e "$(GREEN)✅ ChromaDB restored$(NC)"; \
		fi; \
		echo -e "$(GREEN)✅ Restore complete. Run 'make dev' to start services.$(NC)"; \
	else \
		echo -e "$(RED)Invalid selection$(NC)"; \
	fi

.PHONY: shell
shell: ## Open shell in backend container
	@docker compose exec backend /bin/bash

# ========================================================================
# TROUBLESHOOTING COMMANDS
# ========================================================================

.PHONY: check-requirements
check-requirements: ## Verify required tools are installed
	@echo -e "$(YELLOW)Checking requirements...$(NC)"
	@MISSING_TOOLS=""; \
	command -v docker >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS docker"; \
	docker compose version >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS docker-compose-v2"; \
	command -v python3 >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS python3"; \
	command -v npm >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS npm"; \
	command -v lsof >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS lsof"; \
	command -v jq >/dev/null 2>&1 || MISSING_TOOLS="$$MISSING_TOOLS jq"; \
	if [ -n "$$MISSING_TOOLS" ]; then \
		echo -e "$(RED)❌ Missing required tools:$$MISSING_TOOLS$(NC)"; \
		exit 1; \
	fi; \
	echo -e "$(GREEN)✅ All requirements met$(NC)"

.PHONY: check-ports
check-ports: ## Check if required ports are available
	@echo -e "$(YELLOW)Checking port availability...$(NC)"
	@# Check backend ports (must be available)
	@for port in $(API_PORT) $(CHROMA_GATEWAY_PORT) 11434; do \
		if lsof -i :$$port >/dev/null 2>&1; then \
			echo -e "$(RED)❌ Port $$port is in use$(NC)"; \
			lsof -i :$$port | grep LISTEN | head -1; \
			exit 1; \
		else \
			echo -e "$(GREEN)✅ Port $$port available$(NC)"; \
		fi \
	done
	@# Check frontend port (interactive handling)
	@$(MAKE) check-frontend-port

.PHONY: check-frontend-port
check-frontend-port: ## Check if frontend port is available with interactive handling
	@set +e; \
	PORT_IN_USE=false; \
	if ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		PORT_IN_USE=true; \
	fi; \
	if [ "$$PORT_IN_USE" = "true" ]; then \
		echo -e "$(YELLOW)⚠️  Port $(FRONTEND_PORT) is in use$(NC)"; \
		lsof -i :$(FRONTEND_PORT) | grep LISTEN | head -1 || true; \
		echo -e ""; \
		echo -e "Options:"; \
		echo -e "  1) Stop frontend and retry"; \
		echo -e "  2) Proceed without starting frontend"; \
		echo -e "  3) Skip check and attempt to start anyway"; \
		echo -e ""; \
		read -p "Select option [1-3]: " -r choice; \
		if [ "$$choice" = "1" ]; then \
			echo -e "$(YELLOW)Attempting to stop frontend...$(NC)"; \
			if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
				kill $$(cat .frontend.pid) 2>/dev/null || true; \
				rm -f .frontend.pid; \
				echo -e "$(GREEN)Frontend stopped. Retrying...$(NC)"; \
				sleep 2; \
				$(MAKE) check-frontend-port; \
			else \
				echo -e "$(YELLOW)Please manually terminate the service using port $(FRONTEND_PORT)$(NC)"; \
				echo -e "$(YELLOW)Then run 'make dev' again$(NC)"; \
				exit 1; \
			fi; \
		elif [ "$$choice" = "2" ]; then \
			echo -e "$(YELLOW)Proceeding without frontend...$(NC)"; \
			echo "SKIP_FRONTEND=true" > .frontend.skip; \
		elif [ "$$choice" = "3" ]; then \
			echo -e "$(YELLOW)Skipping port check...$(NC)"; \
			rm -f .frontend.skip; \
		else \
			echo -e "$(RED)Invalid choice. Exiting.$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo -e "$(GREEN)✅ Port $(FRONTEND_PORT) available$(NC)"; \
		rm -f .frontend.skip; \
	fi

.PHONY: troubleshoot
troubleshoot: ## Interactive troubleshooting guide
	@echo -e "$(BLUE)Troubleshooting Guide$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)1. Services won't start:$(NC)"
	@echo -e "   - Check ports: $(GREEN)make check-ports$(NC)"
	@echo -e "   - View logs: $(GREEN)make logs$(NC)"
	@echo -e "   - Reset everything: $(GREEN)make reset$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)2. Health check failures:$(NC)"
	@echo -e "   - View detailed health: $(GREEN)make health$(NC)"
	@echo -e "   - Check container logs: $(GREEN)make logs-backend$(NC)"
	@echo -e "   - Restart services: $(GREEN)make stop && make dev$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)3. Model errors:$(NC)"
	@echo -e "   - Pull models: $(GREEN)make pull-models$(NC)"
	@echo -e "   - Check Ollama: $(GREEN)make logs-ollama$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)4. Frontend issues:$(NC)"
	@echo -e "   - Check frontend log: $(GREEN)tail -f frontend.log$(NC)"
	@echo -e "   - Reinstall deps: $(GREEN)cd $(FRONTEND_DIR) && npm install$(NC)"

.PHONY: logs-backend
logs-backend: ## View backend logs
	@docker compose logs -f backend

.PHONY: logs-chromadb
logs-chromadb: ## View ChromaDB logs
	@docker compose logs -f chromadb

.PHONY: logs-ollama
logs-ollama: ## View Ollama logs
	@docker compose logs -f ollama

# ========================================================================
# INTERNAL HELPERS (not shown in help)
# ========================================================================

# Simple shell functions for port detection
.PHONY: _check_port_in_use
_check_port_in_use:
	@ss -tlnp 2>/dev/null | grep -q ":$$PORT\s" || \
	lsof -i :$$PORT -sTCP:LISTEN >/dev/null 2>&1 || \
	lsof -i4 :$$PORT -sTCP:LISTEN >/dev/null 2>&1 || \
	lsof -i6 :$$PORT -sTCP:LISTEN >/dev/null 2>&1

.PHONY: _get_port_pid
_get_port_pid:
	@ss -tlnp 2>/dev/null | grep ":$$PORT\s" | grep -oP 'pid=\K[0-9]+' | head -1 || \
	lsof -i :$$PORT -sTCP:LISTEN -t 2>/dev/null | head -1 || \
	lsof -i4 :$$PORT -sTCP:LISTEN -t 2>/dev/null | head -1 || \
	lsof -i6 :$$PORT -sTCP:LISTEN -t 2>/dev/null | head -1 || \
	echo ""

.PHONY: ensure-env-files
ensure-env-files:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo -e "$(GREEN)✅ Created .env from example$(NC)"; \
	fi
	@if [ ! -f $(FRONTEND_DIR)/.env.local ]; then \
		cp $(FRONTEND_DIR)/.env.local.example $(FRONTEND_DIR)/.env.local; \
		echo -e "$(GREEN)✅ Created frontend .env.local$(NC)"; \
	fi

.PHONY: setup-backend
setup-backend:
	@if [ ! -d "venv" ]; then \
		echo -e "$(YELLOW)Creating Python virtual environment...$(NC)"; \
		python3 -m venv venv; \
	fi
	@echo -e "$(YELLOW)Installing Python dependencies...$(NC)"
	@./venv/bin/pip install --upgrade pip
	@./venv/bin/pip install -r $(BACKEND_DIR)/requirements.txt
	@./venv/bin/pip install -r $(BACKEND_DIR)/requirements-dev.txt
	@echo -e "$(GREEN)✅ Backend dependencies installed$(NC)"

.PHONY: wait-for-services
wait-for-services:
	@echo -e "Waiting for services to be healthy..."
	@timeout=60; \
	elapsed=0; \
	while [ $$elapsed -lt $$timeout ]; do \
		ALL_HEALTHY=true; \
		for service in backend chromadb ollama; do \
			if ! docker compose ps $$service --format json 2>/dev/null | jq -e '.Health == "healthy"' >/dev/null 2>&1; then \
				ALL_HEALTHY=false; \
				break; \
			fi; \
		done; \
		if [ "$$ALL_HEALTHY" = true ]; then \
			echo ""; \
			echo -e "$(GREEN)✅ All services healthy$(NC)"; \
			break; \
		fi; \
		if [ $$elapsed -eq 0 ]; then \
			echo -n "Waiting"; \
		fi; \
		echo -n "."; \
		sleep 2; \
		elapsed=$$((elapsed + 2)); \
		if [ $$elapsed -ge $$timeout ]; then \
			echo ""; \
			echo -e "$(YELLOW)⚠️  Timeout waiting for services$(NC)"; \
			echo -e "Check status with: $(GREEN)make health-detailed$(NC)"; \
		fi; \
	done

.PHONY: start-frontend-background
start-frontend-background:
	@if [ -f .frontend.skip ]; then \
		echo -e "$(YELLOW)⚠️  Skipping frontend startup (port $(FRONTEND_PORT) was in use)$(NC)"; \
		echo -e "$(YELLOW)To start frontend manually later: cd $(FRONTEND_DIR) && npm run dev$(NC)"; \
	elif [ -f .frontend.pid ]; then \
		PID=$$(cat .frontend.pid); \
		if kill -0 $$PID 2>/dev/null && ps -p $$PID -o comm= 2>/dev/null | grep -q "npm"; then \
			echo -e "$(GREEN)✅ Frontend already running (PID: $$PID)$(NC)"; \
		else \
			echo -e "$(YELLOW)⚠️  Stale PID file detected, cleaning up...$(NC)"; \
			rm -f .frontend.pid; \
			$(MAKE) start-frontend-background; \
		fi; \
	else \
		echo -e "$(YELLOW)Starting frontend...$(NC)"; \
		rm -f .frontend.pid; \
		cd $(FRONTEND_DIR) && nohup npm run dev > ../../frontend.log 2>&1 & \
		FRONTEND_PID=$$!; \
		echo $$FRONTEND_PID > ../../.frontend.pid; \
		echo -e "$(BLUE)Frontend process started with PID: $$FRONTEND_PID$(NC)"; \
		cd ../..; \
		sleep 3; \
		if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
			echo -e "$(YELLOW)Waiting for frontend to be ready...$(NC)"; \
			for i in {1..10}; do \
				if ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
					echo -e "$(GREEN)✅ Frontend started (PID: $$(cat .frontend.pid))$(NC)"; \
					echo -e "$(GREEN)   URL: http://localhost:$(FRONTEND_PORT)$(NC)"; \
					break; \
				fi; \
				sleep 1; \
			done; \
			if ! ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" && ! lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
				echo -e "$(YELLOW)⚠️  Frontend process running but port not ready$(NC)"; \
				echo -e "$(YELLOW)   Check logs: tail -f frontend.log$(NC)"; \
			fi; \
		else \
			echo -e "$(RED)❌ Frontend failed to start$(NC)"; \
			[ -f frontend.log ] && tail -20 frontend.log; \
		fi; \
	fi

.PHONY: stop-frontend
stop-frontend:
	@if [ -f .frontend.pid ]; then \
		FRONTEND_PID=$$(cat .frontend.pid); \
		if kill -0 $$FRONTEND_PID 2>/dev/null; then \
			echo -e "$(YELLOW)Stopping frontend (PID: $$FRONTEND_PID)...$(NC)"; \
			pkill -P $$FRONTEND_PID 2>/dev/null || true; \
			kill $$FRONTEND_PID 2>/dev/null || true; \
			sleep 2; \
			if kill -0 $$FRONTEND_PID 2>/dev/null; then \
				echo -e "$(YELLOW)Frontend still running, sending SIGKILL...$(NC)"; \
				pkill -9 -P $$FRONTEND_PID 2>/dev/null || true; \
				kill -9 $$FRONTEND_PID 2>/dev/null || true; \
			fi; \
			echo -e "$(GREEN)✅ Frontend stopped$(NC)"; \
		else \
			echo -e "$(YELLOW)Frontend PID $$FRONTEND_PID not found (already stopped)$(NC)"; \
		fi; \
		rm -f .frontend.pid; \
	else \
		echo -e "$(YELLOW)No frontend PID file found$(NC)"; \
		EXTERNAL_PID=$$(ss -tlnp 2>/dev/null | grep ":$(FRONTEND_PORT)\s" | grep -oP 'pid=\K[0-9]+' | head -1 || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN -t 2>/dev/null | head -1); \
		if [ -n "$$EXTERNAL_PID" ]; then \
			echo -e "$(YELLOW)Found externally managed frontend (PID: $$EXTERNAL_PID)$(NC)"; \
			echo -e "$(YELLOW)To stop it, run: kill $$EXTERNAL_PID$(NC)"; \
		fi; \
	fi
	@rm -f .frontend.skip

.PHONY: kill-frontend
kill-frontend: ## Force kill any process using the frontend port
	@echo -e "$(YELLOW)Looking for processes on port $(FRONTEND_PORT)...$(NC)"
	@PIDS=$$(ss -tlnp 2>/dev/null | grep ":$(FRONTEND_PORT)\s" | grep -oP 'pid=\K[0-9]+' | head -1 || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN -t 2>/dev/null | head -1); \
	if [ -n "$$PIDS" ]; then \
		echo -e "$(YELLOW)Found process(es): $$PIDS$(NC)"; \
		for pid in $$PIDS; do \
			PROCESS_INFO=$$(ps -p $$pid -o comm= 2>/dev/null || echo "unknown"); \
			echo -e "  Killing PID $$pid ($$PROCESS_INFO)..."; \
			kill -9 $$pid 2>/dev/null || true; \
		done; \
		echo -e "$(GREEN)✅ Killed all processes on port $(FRONTEND_PORT)$(NC)"; \
	else \
		echo -e "$(GREEN)✅ No processes found on port $(FRONTEND_PORT)$(NC)"; \
	fi
	@rm -f .frontend.pid .frontend.skip

.PHONY: check-frontend
check-frontend: ## Detailed check of frontend status
	@echo -e "$(BLUE)Frontend Status Check$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Port $(FRONTEND_PORT) Status:$(NC)"
	@if ss -tlnp 2>/dev/null | grep -q ":$(FRONTEND_PORT)\s" || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo -e "  $(GREEN)✅ Port is in use$(NC)"; \
		echo -e ""; \
		echo -e "$(YELLOW)Process Details:$(NC)"; \
		ss -tlnp 2>/dev/null | grep :$(FRONTEND_PORT) || \
		lsof -i :$(FRONTEND_PORT) -P 2>/dev/null | grep -v "^COMMAND" || \
		lsof -i4 :$(FRONTEND_PORT) -P 2>/dev/null | grep -v "^COMMAND" || \
		lsof -i6 :$(FRONTEND_PORT) -P 2>/dev/null | grep -v "^COMMAND" || true; \
		echo -e ""; \
		PID=$$(ss -tlnp 2>/dev/null | grep ":$(FRONTEND_PORT)\s" | grep -oP 'pid=\K[0-9]+' | head -1 || lsof -i :$(FRONTEND_PORT) -sTCP:LISTEN -t 2>/dev/null | head -1); \
		if [ -n "$$PID" ]; then \
			echo -e "$(YELLOW)Process Info (PID $$PID):$(NC)"; \
			ps -p $$PID -o pid,ppid,user,comm,args | tail -n +2 || true; \
		fi; \
	else \
		echo -e "  $(RED)❌ Port is not in use$(NC)"; \
	fi
	@echo -e ""
	@echo -e "$(YELLOW)Frontend Management Files:$(NC)"
	@if [ -f .frontend.pid ]; then \
		echo -e "  .frontend.pid exists (PID: $$(cat .frontend.pid))"; \
		if kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
			echo -e "    $(GREEN)Process is running$(NC)"; \
		else \
			echo -e "    $(RED)Process is NOT running (stale PID file)$(NC)"; \
		fi; \
	else \
		echo -e "  .frontend.pid: $(YELLOW)Not found$(NC)"; \
	fi
	@if [ -f .frontend.skip ]; then \
		echo -e "  .frontend.skip: $(YELLOW)Exists (frontend was skipped)$(NC)"; \
	else \
		echo -e "  .frontend.skip: Not found"; \
	fi

.PHONY: show-status
show-status:
	@echo -e "$(GREEN)Services running at:$(NC)"
	@if [ -f .frontend.skip ]; then \
		echo -e "  Frontend:    $(YELLOW)Skipped (port $(FRONTEND_PORT) was in use)$(NC)"; \
	else \
		echo -e "  Frontend:    http://localhost:$(FRONTEND_PORT)"; \
	fi
	@echo -e "  Backend API: http://localhost:$(API_PORT)"
	@echo -e "  API Docs:    http://localhost:$(API_PORT)/docs"
	@echo -e "  ChromaDB:    http://localhost:$(CHROMA_GATEWAY_PORT)"

.PHONY: check-models
check-models: ## Check which Ollama models are installed
	@echo -e "$(YELLOW)Checking Ollama models...$(NC)"
	@OLLAMA_HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q ollama 2>/dev/null) 2>/dev/null || echo "not-running"); \
	if [ "$$OLLAMA_HEALTH" != "healthy" ]; then \
		echo -e "$(RED)❌ Cannot check models - Ollama is $$OLLAMA_HEALTH$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Installed models:$(NC)"
	@docker compose exec ollama ollama list 2>/dev/null || echo "No models found"
	@echo -e ""
	@echo -e "$(BLUE)Required models:$(NC)"
	@echo -e "  - $(YELLOW)gemma3n:e2b$(NC) (Generative model)"
	@echo -e "  - $(YELLOW)mxbai-embed-large:latest$(NC) (Embedding model)"
	@echo -e "  - $(YELLOW)linux6200/bge-reranker-v2-m3:latest$(NC) (Reranker model)"

.PHONY: pull-models
pull-models: ## Pull required Ollama models
	@echo -e "$(YELLOW)Pulling Ollama models...$(NC)"
	@# Check if Ollama is healthy before pulling models
	@OLLAMA_HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q ollama 2>/dev/null) 2>/dev/null || echo "not-running"); \
	if [ "$$OLLAMA_HEALTH" != "healthy" ]; then \
		echo -e "$(RED)❌ Cannot pull models - Ollama is $$OLLAMA_HEALTH$(NC)"; \
		echo -e "Run $(GREEN)make health-detailed$(NC) for more information"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Pulling models in parallel for faster download...$(NC)"
	@docker compose exec -T ollama ollama pull gemma3n:e2b & \
	docker compose exec -T ollama ollama pull mxbai-embed-large & \
	docker compose exec -T ollama ollama pull linux6200/bge-reranker-v2-m3 & \
	wait
	@echo -e "$(GREEN)✅ All models pulled successfully$(NC)"

.PHONY: interactive-pull-models
interactive-pull-models: ## Interactive model pull with user prompts
	@echo -e "$(BLUE)Ollama Model Manager$(NC)"
	@echo -e ""
	@# Check if Ollama is healthy
	@OLLAMA_HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q ollama 2>/dev/null) 2>/dev/null || echo "not-running"); \
	if [ "$$OLLAMA_HEALTH" != "healthy" ]; then \
		echo -e "$(RED)❌ Cannot manage models - Ollama is $$OLLAMA_HEALTH$(NC)"; \
		exit 1; \
	fi
	@# Check installed models
	@INSTALLED_MODELS=$$(docker compose exec ollama ollama list 2>/dev/null | tail -n +2 | awk '{print $$1}' | sort | uniq || echo ""); \
	REQUIRED_MODELS="gemma3n:e2b mxbai-embed-large:latest linux6200/bge-reranker-v2-m3:latest"; \
	MISSING_MODELS=""; \
	for model in $$REQUIRED_MODELS; do \
		if ! echo "$$INSTALLED_MODELS" | grep -q "^$$model$$"; then \
			MISSING_MODELS="$$MISSING_MODELS $$model"; \
		fi; \
	done; \
	if [ -z "$$MISSING_MODELS" ]; then \
		echo -e "$(GREEN)✅ All required models are already installed!$(NC)"; \
		echo -e ""; \
		docker compose exec ollama ollama list; \
		exit 0; \
	fi; \
	echo -e "$(YELLOW)Missing models:$(NC)"; \
	echo -e ""; \
	n=1; \
	for model in $$MISSING_MODELS; do \
		case $$model in \
			gemma3n:e2b) \
				echo -e "  $$n) $(YELLOW)$$model$(NC) - Generative AI model (for chat responses)" ;; \
			mxbai-embed-large) \
				echo -e "  $$n) $(YELLOW)$$model$(NC) - Embedding model (for document search)" ;; \
			linux6200/bge-reranker-v2-m3) \
				echo -e "  $$n) $(YELLOW)$$model$(NC) - Reranker model (for search result ranking)" ;; \
		esac; \
		n=$$((n+1)); \
	done; \
	echo -e "  A) Pull all missing models"; \
	echo -e "  S) Skip for now"; \
	echo -e ""; \
	read -p "Select option(s) [1-$$((n-1)), A, or S]: " -r choice; \
	if [[ "$$choice" =~ ^[Ss]$$ ]]; then \
		echo -e "$(YELLOW)Skipping model pull. Note: Synapse may not function properly without all models.$(NC)"; \
		exit 0; \
	elif [[ "$$choice" =~ ^[Aa]$$ ]]; then \
		echo -e "$(YELLOW)Pulling all missing models...$(NC)"; \
		for model in $$MISSING_MODELS; do \
			echo -e "$(BLUE)Pulling $$model...$(NC)"; \
			docker compose exec ollama ollama pull $$model || echo -e "$(RED)Failed to pull $$model$(NC)"; \
		done; \
	else \
		n=1; \
		for model in $$MISSING_MODELS; do \
			if [[ "$$choice" =~ $$n ]]; then \
				echo -e "$(BLUE)Pulling $$model...$(NC)"; \
				docker compose exec ollama ollama pull $$model || echo -e "$(RED)Failed to pull $$model$(NC)"; \
			fi; \
			n=$$((n+1)); \
		done; \
	fi; \
	echo -e ""; \
	echo -e "$(GREEN)✅ Model management complete$(NC)"; \
	echo -e ""; \
	echo -e "$(BLUE)Currently installed models:$(NC)"; \
	docker compose exec ollama ollama list

# ========================================================================
# DEVELOPMENT SHORTCUTS
# ========================================================================

.PHONY: rebuild
rebuild: ## Rebuild containers (no cache)
	@echo -e "$(YELLOW)Rebuilding containers...$(NC)"
	@docker compose build --no-cache
	@echo -e "$(GREEN)✅ Rebuild complete$(NC)"

.PHONY: restart
restart: ## Restart specific service (usage: make restart service=backend)
	@if [ -z "$(service)" ]; then \
		echo -e "$(RED)Usage: make restart service=<service-name>$(NC)"; \
		echo -e "Available: backend, chromadb, ollama"; \
	else \
		docker compose restart $(service); \
		echo -e "$(GREEN)✅ Restarted $(service)$(NC)"; \
	fi

.PHONY: fresh
fresh: ## Complete fresh start (clean + init + dev)
	@$(MAKE) clean
	@$(MAKE) reset
	@$(MAKE) init
	@$(MAKE) dev