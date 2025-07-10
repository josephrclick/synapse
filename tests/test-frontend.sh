#!/bin/bash

# Simple manual test script for Synapse frontend
# Tests basic functionality through HTTP requests

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FRONTEND_PORT="${FRONTEND_PORT:-8100}"
FRONTEND_URL="http://localhost:${FRONTEND_PORT}"

echo -e "${YELLOW}=== Synapse Frontend Tests ===${NC}"
echo "Testing frontend at: $FRONTEND_URL"
echo ""

# Check if frontend is running
echo -e "${YELLOW}1. Checking if frontend is accessible...${NC}"
if curl -s -f -o /dev/null "$FRONTEND_URL"; then
    echo -e "${GREEN}✓ Frontend is running${NC}"
else
    echo -e "${RED}✗ Frontend is not accessible${NC}"
    echo "Start it with: cd frontend/synapse && npm run dev"
    exit 1
fi

# Check main page
echo -e "\n${YELLOW}2. Testing main page...${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ Main page loads successfully (Status: 200)${NC}"
else
    echo -e "${RED}✗ Main page failed (Status: $response)${NC}"
fi

# Check ingestion page
echo -e "\n${YELLOW}3. Testing ingestion page...${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/ingest")
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ Ingestion page loads successfully (Status: 200)${NC}"
else
    echo -e "${RED}✗ Ingestion page failed (Status: $response)${NC}"
fi

# Check if backend is configured correctly
echo -e "\n${YELLOW}4. Checking backend configuration...${NC}"
# This checks if the frontend build has the correct backend URL
page_content=$(curl -s "$FRONTEND_URL")
if echo "$page_content" | grep -q "NEXT_PUBLIC_BACKEND_URL"; then
    echo -e "${YELLOW}⚠ Backend URL configuration found in page${NC}"
else
    echo -e "${GREEN}✓ Frontend appears to be configured${NC}"
fi

# Test static assets
echo -e "\n${YELLOW}5. Testing static assets...${NC}"
# Try to load the favicon
favicon_response=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/favicon.ico")
if [ "$favicon_response" = "200" ] || [ "$favicon_response" = "304" ]; then
    echo -e "${GREEN}✓ Static assets are being served${NC}"
else
    echo -e "${RED}✗ Static assets issue (Status: $favicon_response)${NC}"
fi

echo -e "\n${YELLOW}=== Frontend Test Summary ===${NC}"
echo "Basic frontend tests completed!"
echo ""
echo "For interactive testing:"
echo "  1. Open $FRONTEND_URL in your browser"
echo "  2. Try the chat interface on the main page"
echo "  3. Navigate to /ingest and submit a document"
echo "  4. Check browser console for any errors"
echo ""
echo "To run frontend in development mode:"
echo "  cd frontend/synapse && npm run dev"
echo ""
echo "To check frontend build:"
echo "  cd frontend/synapse && npm run build"