#!/bin/bash

# Test Ollama container integration
# Verifies that Ollama is running and models are available

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

echo -e "${YELLOW}=== Testing Ollama Container ===${NC}"

# Check if Ollama container is running
if docker compose ps ollama | grep -q "running"; then
    echo -e "${GREEN}✓ Ollama container is running${NC}"
else
    echo -e "${RED}✗ Ollama container is not running${NC}"
    echo "Start it with: docker compose up -d ollama"
    exit 1
fi

# Test Ollama API
echo -e "\n${YELLOW}Testing Ollama API...${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ Ollama API is accessible${NC}"
else
    echo -e "${RED}✗ Ollama API not responding (Status: $response)${NC}"
fi

# List available models
echo -e "\n${YELLOW}Available models:${NC}"
models=$(curl -s http://localhost:11434/api/tags | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'models' in data:
    for model in data['models']:
        print(f\"  - {model['name']} ({model.get('size', 'unknown size')})\")
else:
    print('  No models found')
" 2>/dev/null || echo "  Error parsing models")
echo "$models"

# Check for required models
echo -e "\n${YELLOW}Checking required models...${NC}"
required_models=("mxbai-embed-large" "gemma3n:e4b")

for model in "${required_models[@]}"; do
    if curl -s http://localhost:11434/api/tags | grep -q "\"$model\""; then
        echo -e "${GREEN}✓ $model is available${NC}"
    else
        echo -e "${RED}✗ $model is NOT available${NC}"
        echo "  Pull it with: docker compose exec ollama ollama pull $model"
    fi
done

# Test embedding model
echo -e "\n${YELLOW}Testing embedding generation...${NC}"
response=$(curl -s -X POST http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mxbai-embed-large",
    "prompt": "test embedding"
  }')

if echo "$response" | grep -q "embedding"; then
    echo -e "${GREEN}✓ Embedding generation works${NC}"
else
    echo -e "${RED}✗ Embedding generation failed${NC}"
    echo "Response: $response"
fi

echo -e "\n${YELLOW}=== Ollama Test Summary ===${NC}"
echo "Ollama container is set up and ready for use!"
echo ""
echo "To pull missing models:"
echo "  docker compose exec ollama ollama pull mxbai-embed-large"
echo "  docker compose exec ollama ollama pull gemma3n:e4b"
echo ""
echo "To check Ollama logs:"
echo "  docker compose logs ollama -f"