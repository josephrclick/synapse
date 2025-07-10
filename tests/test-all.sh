#!/bin/bash

# Comprehensive test script for Synapse
# Runs all manual tests and provides a summary

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project root for docker compose commands
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}    Synapse Comprehensive Tests    ${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker Desktop"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Check if containers are running
if docker compose ps | grep -q "synapse-backend.*running"; then
    echo -e "${GREEN}✓ Backend container is running${NC}"
else
    echo -e "${RED}✗ Backend container is not running${NC}"
    echo "Start with: make run-all"
    exit 1
fi

if docker compose ps | grep -q "synapse-chromadb.*running"; then
    echo -e "${GREEN}✓ ChromaDB container is running${NC}"
else
    echo -e "${RED}✗ ChromaDB container is not running${NC}"
    echo "Start with: make run-all"
    exit 1
fi

# Check if frontend is running
FRONTEND_PORT="${FRONTEND_PORT:-8100}"
if curl -s -f -o /dev/null "http://localhost:${FRONTEND_PORT}"; then
    echo -e "${GREEN}✓ Frontend is running${NC}"
else
    echo -e "${YELLOW}⚠ Frontend is not running${NC}"
    echo "  Start with: cd frontend/synapse && npm run dev"
    echo "  Skipping frontend tests..."
    SKIP_FRONTEND=true
fi

echo ""

# Run backend API tests
echo -e "${BLUE}=== Running Backend API Tests ===${NC}"
"$SCRIPT_DIR/test-backend-api.sh"
echo ""

# Run pytest tests in container (optional)
echo -e "${BLUE}=== Running Pytest Tests (Optional) ===${NC}"
read -p "Run comprehensive pytest suite in Docker? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/test-backend-pytest.sh"
else
    echo "Skipping pytest tests"
fi
echo ""

# Run frontend tests if available
if [ -z "$SKIP_FRONTEND" ]; then
    echo -e "${BLUE}=== Running Frontend Tests ===${NC}"
    "$SCRIPT_DIR/test-frontend.sh"
    echo ""
fi

# Summary
echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}         Test Summary              ${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo -e "${GREEN}✓ Backend API tests completed${NC}"
if [ -z "$SKIP_FRONTEND" ]; then
    echo -e "${GREEN}✓ Frontend tests completed${NC}"
else
    echo -e "${YELLOW}⚠ Frontend tests skipped (not running)${NC}"
fi
echo ""
echo "Next steps:"
echo "  - Check logs: make logs"
echo "  - Test interactively: Open http://localhost:${FRONTEND_PORT}"
echo "  - Run specific tests: cd tests && ./test-backend-api.sh"
echo ""