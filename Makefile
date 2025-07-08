# Load environment variables
include .env
export

.PHONY: test run setup clean lint help run-backend run-frontend run-all test-all stop-all logs check-ports

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup:  ## Setup virtual environment and install dependencies
	python3 -m venv venv
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install -r backend/requirements.txt
	./venv/bin/pip install -r backend/requirements-dev.txt

run:  ## Start the backend server (alias for run-backend)
	./backend/setup_and_run.sh

run-backend:  ## Start backend API server
	@echo "Starting backend API on port $(API_PORT)..."
	cd backend && ./setup_and_run.sh

run-frontend:  ## Start frontend dev server
	@echo "Starting frontend dev server on port $(FRONTEND_PORT)..."
	cd frontend/capture-v3 && npm run dev

run-all:  ## Start all services (docker + frontend)
	@echo "Starting all services..."
	docker compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Starting frontend..."
	cd frontend/capture-v3 && npm run dev

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

stop-all:  ## Stop all docker services
	@echo "Stopping all docker services..."
	docker compose down

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

clean:  ## Clean cache and temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true