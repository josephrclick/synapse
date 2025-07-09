#!/bin/bash
# Start backend locally without Docker

# Source the virtual environment
source venv/bin/activate

# Export environment variables
export $(cat .env.development | grep -v '^#' | xargs)

# Override some settings for local development
export CHROMA_HOST=localhost
export CHROMA_PORT=8102
export OLLAMA_BASE_URL=http://localhost:11434

# Start the backend
uvicorn main:app --host 0.0.0.0 --port 8101 --reload