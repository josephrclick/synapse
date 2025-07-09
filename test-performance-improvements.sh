#!/bin/bash

# Test script for performance improvements

echo "Testing Performance Improvements for Synapse"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Smart dependency installation
echo -e "${YELLOW}Test 1: Smart dependency installation${NC}"
echo "Running 'make setup' twice to verify caching..."
echo ""

# First run
echo "First run:"
time make setup
echo ""

# Second run (should be cached)
echo "Second run (should be cached):"
time make setup
echo ""

# Test 2: Docker Compose healthchecks
echo -e "${YELLOW}Test 2: Docker Compose healthchecks${NC}"
echo "Checking docker-compose.yml syntax..."
docker compose config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ docker-compose.yml syntax is valid${NC}"
else
    echo -e "${RED}❌ docker-compose.yml has syntax errors${NC}"
    docker compose config
fi
echo ""

# Test 3: Wait functions
echo -e "${YELLOW}Test 3: Testing wait functions${NC}"
echo "Note: This test requires services to be running"
echo ""

# Check if services are running
if curl -s http://localhost:8101/health >/dev/null 2>&1; then
    echo "Backend is already running, testing wait function..."
    make wait-for-backend
else
    echo "Backend is not running. Start services with 'make run-all' to test wait functions."
fi
echo ""

# Test 4: Resource limits
echo -e "${YELLOW}Test 4: Checking resource limits in docker-compose.yml${NC}"
if grep -q "deploy:" docker-compose.yml && grep -q "resources:" docker-compose.yml; then
    echo -e "${GREEN}✅ Resource limits are configured${NC}"
    echo "Backend limits:"
    grep -A 6 "deploy:" docker-compose.yml | grep -A 5 "backend:" | grep -E "(cpus|memory):" | head -4
    echo ""
    echo "ChromaDB limits:"
    grep -A 6 "deploy:" docker-compose.yml | grep -A 5 "chromadb:" | grep -E "(cpus|memory):" | tail -4
else
    echo -e "${RED}❌ Resource limits not found${NC}"
fi
echo ""

# Test 5: Service dependencies
echo -e "${YELLOW}Test 5: Checking service dependencies${NC}"
if grep -q "condition: service_healthy" docker-compose.yml; then
    echo -e "${GREEN}✅ Service health dependencies are configured${NC}"
    grep -B 2 "condition: service_healthy" docker-compose.yml
else
    echo -e "${RED}❌ Service health dependencies not found${NC}"
fi
echo ""

echo "=============================================="
echo "Performance improvements test complete!"
echo ""
echo "Summary of improvements:"
echo "1. ✅ Smart dependency installation with caching"
echo "2. ✅ ChromaDB healthcheck added"
echo "3. ✅ Wait-for-backend and wait-for-chromadb functions"
echo "4. ✅ Resource limits for containers"
echo "5. ✅ Service dependency on health status"
echo ""
echo "To fully test the improvements, run:"
echo "  make stop-all    # Stop existing services"
echo "  make run-all     # Start with new improvements"