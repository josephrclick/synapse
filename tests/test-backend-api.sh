#!/bin/bash

# Simple manual test script for Synapse backend API
# Works with Docker containerized setup

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from environment
API_PORT="${API_PORT:-8101}"
API_URL="http://localhost:${API_PORT}"
API_KEY="${BACKEND_API_KEY:-test-api-key-123}"

echo -e "${YELLOW}=== Synapse Backend API Tests ===${NC}"
echo "Testing API at: $API_URL"
echo "Using API Key: $API_KEY"
echo ""

# Helper function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    
    echo -e "${YELLOW}Testing: $method $endpoint${NC}"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "X-API-Key: $API_KEY" \
            "$API_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "${GREEN}✓ Status: $http_code (expected)${NC}"
    else
        echo -e "${RED}✗ Status: $http_code (expected: $expected_status)${NC}"
    fi
    
    echo "Response: $body" | python3 -m json.tool 2>/dev/null || echo "Response: $body"
    echo ""
    
    # Return the response for further processing
    echo "$body" > /tmp/last_response.json
}

# Function to wait for document processing
wait_for_processing() {
    local doc_id=$1
    local max_attempts=30
    local attempt=0
    
    echo -e "${YELLOW}Waiting for document processing...${NC}"
    
    while [ $attempt -lt $max_attempts ]; do
        response=$(curl -s -X GET \
            -H "X-API-Key: $API_KEY" \
            "$API_URL/api/documents/$doc_id")
        
        status=$(echo "$response" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "error")
        
        if [ "$status" = "completed" ]; then
            echo -e "${GREEN}✓ Document processed successfully!${NC}"
            return 0
        elif [ "$status" = "failed" ]; then
            echo -e "${RED}✗ Document processing failed${NC}"
            echo "$response" | python3 -m json.tool
            return 1
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    echo -e "${RED}✗ Timeout waiting for document processing${NC}"
    return 1
}

# 1. Test Health Check
echo -e "\n${YELLOW}=== 1. Health Check ===${NC}"
api_call GET /health "" 200

# 2. Test API Key Validation
echo -e "\n${YELLOW}=== 2. API Key Validation ===${NC}"
echo "Testing missing API key..."
response=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/api/documents")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "403" ]; then
    echo -e "${GREEN}✓ Correctly rejected request without API key${NC}"
else
    echo -e "${RED}✗ Expected 403, got $http_code${NC}"
fi
echo ""

# 3. Test Document Creation
echo -e "\n${YELLOW}=== 3. Document Creation ===${NC}"
doc_data='{
    "type": "general_note",
    "title": "Test Document from Manual Test",
    "content": "This is a test document created by the manual test script. It contains information about Synapse, FastAPI, and the RAG pipeline for testing purposes.",
    "tags": ["test", "manual", "api-test"]
}'

api_call POST /api/documents "$doc_data" 202

# Extract document ID from response
doc_id=$(cat /tmp/last_response.json | python3 -c "import json, sys; print(json.load(sys.stdin)['doc_id'])" 2>/dev/null || echo "")

if [ -n "$doc_id" ]; then
    echo -e "${GREEN}✓ Document created with ID: $doc_id${NC}"
    
    # Wait for processing
    if wait_for_processing "$doc_id"; then
        
        # 4. Test Chat Query
        echo -e "\n${YELLOW}=== 4. Chat Query ===${NC}"
        sleep 2  # Give indexing time to propagate
        
        chat_data='{
            "query": "What information do you have about the RAG pipeline?",
            "context_limit": 5
        }'
        
        api_call POST /api/chat "$chat_data" 200
        
        # 5. Test Document Retrieval
        echo -e "\n${YELLOW}=== 5. Document Retrieval ===${NC}"
        api_call GET "/api/documents/$doc_id" "" 200
    fi
fi

# 6. Test Document Listing
echo -e "\n${YELLOW}=== 6. Document Listing ===${NC}"
api_call GET "/api/documents?limit=5" "" 200

# 7. Test Error Handling
echo -e "\n${YELLOW}=== 7. Error Handling ===${NC}"

echo "Testing non-existent document..."
api_call GET "/api/documents/non-existent-id" "" 404

echo "Testing invalid document data..."
invalid_doc='{
    "type": "invalid_type",
    "title": "",
    "content": "Test"
}'
api_call POST /api/documents "$invalid_doc" 422

echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo "All basic API tests completed!"
echo ""
echo "To run more comprehensive tests with pytest:"
echo "  cd backend && ./run_tests.sh"
echo ""
echo "To test specific features:"
echo "  - Document ingestion: ./test-form-submission.sh"
echo "  - Frontend chat: Open http://localhost:${FRONTEND_PORT:-8100}"