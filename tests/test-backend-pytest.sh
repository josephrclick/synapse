#!/bin/bash

# Run pytest tests inside the Docker container
# This avoids dependency issues on the host

set -e

# Get project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project root for docker compose commands
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Running Backend Tests in Docker ===${NC}"

# Check if backend container is running
if ! docker compose ps backend | grep -q "running"; then
    echo -e "${RED}Error: Backend container is not running${NC}"
    echo "Start it with: make run-all"
    exit 1
fi

# Run tests inside the container
echo -e "\n${YELLOW}Running pytest inside backend container...${NC}"
echo ""

# Execute pytest in the container
docker compose exec backend pytest tests/ -v -s

echo -e "\n${GREEN}✓ Tests completed!${NC}"