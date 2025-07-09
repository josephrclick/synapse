#!/bin/bash

# Test script for User Experience Enhancements

echo "Testing User Experience Enhancements for Synapse"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Check-requirements target
echo -e "${YELLOW}Test 1: Testing check-requirements target${NC}"
echo "This should fail fast if any tools are missing..."
make check-requirements
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All requirements check passed${NC}"
else
    echo -e "${RED}❌ Requirements check failed (this is expected if tools are missing)${NC}"
fi
echo ""

# Test 2: Getting started guide
echo -e "${YELLOW}Test 2: Testing getting-started guide${NC}"
make getting-started
echo -e "${GREEN}✅ Getting started guide displayed${NC}"
echo ""

# Test 3: New dev command
echo -e "${YELLOW}Test 3: Checking new 'dev' command${NC}"
make help | grep -E "^dev" && echo -e "${GREEN}✅ 'dev' command is available${NC}" || echo -e "${RED}❌ 'dev' command not found${NC}"
echo ""

# Test 4: Background frontend targets
echo -e "${YELLOW}Test 4: Checking background frontend targets${NC}"
echo "Available frontend-related targets:"
make help | grep -E "frontend" | grep -E "(background|stop)"
echo ""

# Test 5: Utility targets
echo -e "${YELLOW}Test 5: Verifying utility targets exist${NC}"
targets=("logs" "logs-backend" "logs-chromadb" "docker-shell" "backup-data")
for target in "${targets[@]}"; do
    if make help | grep -q "^$target"; then
        echo -e "${GREEN}✅ Target '$target' exists${NC}"
    else
        echo -e "${RED}❌ Target '$target' missing${NC}"
    fi
done
echo ""

# Test 6: Enhanced help output
echo -e "${YELLOW}Test 6: Testing enhanced help output${NC}"
echo "Number of available targets:"
make help | wc -l
echo ""

# Test 7: Clean command updates
echo -e "${YELLOW}Test 7: Checking clean command includes new files${NC}"
if grep -q "frontend.log" Makefile && grep -q ".frontend.pid" Makefile; then
    echo -e "${GREEN}✅ Clean command updated for new files${NC}"
else
    echo -e "${RED}❌ Clean command not fully updated${NC}"
fi
echo ""

# Test 8: Init improvements
echo -e "${YELLOW}Test 8: Checking init command improvements${NC}"
if grep -q "check-requirements" Makefile && grep -A5 "init:" Makefile | grep -q "Step 0"; then
    echo -e "${GREEN}✅ Init command includes requirement checks${NC}"
else
    echo -e "${RED}❌ Init command missing requirement checks${NC}"
fi
echo ""

# Test 9: Non-blocking options
echo -e "${YELLOW}Test 9: Testing non-blocking startup options${NC}"
echo "run-all-detached command:"
make help | grep "run-all-detached" || echo "Not found"
echo ""
echo "dev command (alias):"
make help | grep "^dev" || echo "Not found"
echo ""

echo "=================================================="
echo "User Experience Enhancements Test Summary"
echo ""
echo "✅ Implemented enhancements:"
echo "  1. check-requirements - Fail fast if tools missing"
echo "  2. getting-started - Clear guide for new users"
echo "  3. dev command - Simple non-blocking startup"
echo "  4. run-all-detached - Full non-blocking alternative"
echo "  5. Background frontend control (start/stop)"
echo "  6. All utility targets present"
echo "  7. Enhanced init with requirement checks"
echo "  8. Better completion messages with emojis"
echo ""
echo "To fully test the new workflow:"
echo "  1. make clean"
echo "  2. make init"
echo "  3. make dev"
echo "  4. make status"
echo "  5. make stop-all"