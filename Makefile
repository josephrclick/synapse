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
.SHELLFLAGS := -eu -o pipefail -c

# Load environment variables
-include .env
export

# Default values
FRONTEND_PORT ?= 8100
API_PORT ?= 8101
CHROMA_GATEWAY_PORT ?= 8102
FRONTEND_DIR ?= frontend/synapse
BACKEND_DIR ?= backend

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
	@echo -e "  $(GREEN)reset          $(NC) Reset all services and data"
	@echo -e "  $(GREEN)backup         $(NC) Backup data (SQLite + ChromaDB)"
	@echo -e "  $(GREEN)restore        $(NC) Restore from backup"
	@echo -e "  $(GREEN)shell          $(NC) Open shell in backend container"
	@echo -e "  $(GREEN)pull-models    $(NC) Pull required Ollama models"
	@echo -e ""
	@echo -e "$(YELLOW)Troubleshooting:$(NC)"
	@echo -e "  $(GREEN)check-requirements$(NC) Verify required tools are installed"
	@echo -e "  $(GREEN)check-ports    $(NC) Check if required ports are available"
	@echo -e "  $(GREEN)troubleshoot   $(NC) Interactive troubleshooting guide"
	@echo -e "  $(GREEN)logs-backend   $(NC) View backend logs"
	@echo -e "  $(GREEN)logs-chromadb  $(NC) View ChromaDB logs"
	@echo -e "  $(GREEN)logs-ollama    $(NC) View Ollama logs"
	@echo -e ""
	@echo -e "$(YELLOW)Shortcuts:$(NC)"
	@echo -e "  $(GREEN)rebuild        $(NC) Rebuild containers (no cache)"
	@echo -e "  $(GREEN)restart        $(NC) Restart specific service"
	@echo -e "  $(GREEN)fresh          $(NC) Complete fresh start"

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
	@docker compose up -d
	@echo -e ""
	@echo -e "$(YELLOW)Waiting for services to be healthy...$(NC)"
	@$(MAKE) wait-for-services
	@echo -e ""
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
	@docker compose down
	@$(MAKE) stop-frontend
	@echo -e "$(GREEN)✅ All services stopped$(NC)"

.PHONY: status
status: ## Show service status and health
	@echo -e "$(BLUE)Service Status$(NC)"
	@echo -e ""
	@echo -e "$(YELLOW)Containers:$(NC)"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo -e ""
	@echo -e "$(YELLOW)Frontend:$(NC)"
	@if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
		echo -e "  $(GREEN)✅ Running$(NC) (PID: $$(cat .frontend.pid))"; \
		echo -e "  http://localhost:$(FRONTEND_PORT)"; \
	else \
		echo -e "  $(RED)❌ Not running$(NC)"; \
	fi
	@echo -e ""
	@$(MAKE) health --no-print-directory

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
	@find . -type f -name "*.pyc" -delete
	@rm -f .frontend.pid frontend.log
	@echo -e "$(GREEN)✅ Cleaned$(NC)"

# ========================================================================
# MANAGEMENT COMMANDS
# ========================================================================

.PHONY: health
health: ## Show detailed health status
	@echo -e "$(YELLOW)Health Check:$(NC)"
	@if curl -s -H "X-API-KEY: $${BACKEND_API_KEY:-test-api-key-123}" \
		http://localhost:$(API_PORT)/health 2>/dev/null | jq . 2>/dev/null; then \
		true; \
	else \
		echo -e "$(RED)Backend API is not accessible$(NC)"; \
		echo -e "Services may still be starting up..."; \
	fi

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
			sleep 5; \
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
	@command -v docker >/dev/null 2>&1 || { echo -e "$(RED)❌ Docker is required$(NC)"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo -e "$(RED)❌ Docker Compose v2 is required$(NC)"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo -e "$(RED)❌ Python 3 is required$(NC)"; exit 1; }
	@command -v npm >/dev/null 2>&1 || { echo -e "$(RED)❌ npm is required$(NC)"; exit 1; }
	@echo -e "$(GREEN)✅ All requirements met$(NC)"

.PHONY: check-ports
check-ports: ## Check if required ports are available
	@echo -e "$(YELLOW)Checking port availability...$(NC)"
	@for port in $(REQUIRED_PORTS); do \
		if lsof -i :$$port >/dev/null 2>&1; then \
			echo -e "$(RED)❌ Port $$port is in use$(NC)"; \
			lsof -i :$$port | grep LISTEN | head -1; \
			exit 1; \
		else \
			echo -e "$(GREEN)✅ Port $$port available$(NC)"; \
		fi \
	done

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
	@echo -n "Waiting for services to be healthy"
	@for i in {1..30}; do \
		if docker compose ps | grep -E "(health: starting|unhealthy)" >/dev/null 2>&1; then \
			echo -n "."; \
			sleep 2; \
		else \
			echo ""; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo ""; \
			echo -e "$(YELLOW)⚠️  Some services may not be fully healthy$(NC)"; \
			echo -e "Check status with: $(GREEN)make status$(NC)"; \
		fi; \
	done

.PHONY: start-frontend-background
start-frontend-background:
	@if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
		echo -e "$(GREEN)✅ Frontend already running$(NC)"; \
	else \
		echo -e "$(YELLOW)Starting frontend...$(NC)"; \
		cd $(FRONTEND_DIR) && nohup npm run dev > ../../frontend.log 2>&1 & echo $$! > ../../.frontend.pid; \
		sleep 5; \
		if [ -f .frontend.pid ] && kill -0 $$(cat .frontend.pid) 2>/dev/null; then \
			echo -e "$(GREEN)✅ Frontend started$(NC)"; \
		else \
			echo -e "$(RED)❌ Frontend failed to start$(NC)"; \
			[ -f frontend.log ] && tail -20 frontend.log; \
		fi; \
	fi

.PHONY: stop-frontend
stop-frontend:
	@if [ -f .frontend.pid ]; then \
		kill $$(cat .frontend.pid) 2>/dev/null || true; \
		rm -f .frontend.pid; \
		echo -e "$(GREEN)✅ Frontend stopped$(NC)"; \
	fi

.PHONY: show-status
show-status:
	@echo -e "$(GREEN)Services running at:$(NC)"
	@echo -e "  Frontend:    http://localhost:$(FRONTEND_PORT)"
	@echo -e "  Backend API: http://localhost:$(API_PORT)"
	@echo -e "  API Docs:    http://localhost:$(API_PORT)/docs"
	@echo -e "  ChromaDB:    http://localhost:$(CHROMA_GATEWAY_PORT)"

.PHONY: pull-models
pull-models: ## Pull required Ollama models
	@echo -e "$(YELLOW)Pulling Ollama models...$(NC)"
	@docker compose exec ollama ollama pull mxbai-embed-large
	@docker compose exec ollama ollama pull gemma2:9b
	@echo -e "$(GREEN)✅ Models pulled$(NC)"

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