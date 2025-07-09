#!/bin/bash
set -euo pipefail
# Setup and run script for the backend

# Parse command line arguments
NON_INTERACTIVE=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -y|--yes|--non-interactive) NON_INTERACTIVE=true; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

echo "Setting up Synapse Backend..."

# Change to project root
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r backend/requirements.txt

# Change to backend directory
cd backend

# Check for .env file
if [ ! -f ".env" ]; then
    # Check if .env.example exists
    if [ -f ".env.example" ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        
        # Generate or use existing API key
        if [ -z "${INTERNAL_API_KEY:-}" ]; then
            if [ "$NON_INTERACTIVE" = true ] || [ -n "${CI:-}" ]; then
                # Non-interactive mode: generate key automatically
                INTERNAL_API_KEY=$(openssl rand -hex 32)
                echo "Generated API key: $INTERNAL_API_KEY"
            else
                # Interactive mode: prompt user
                echo ""
                echo "No API key found in environment."
                read -p "Enter API key (press Enter to auto-generate): " user_key
                if [ -z "$user_key" ]; then
                    INTERNAL_API_KEY=$(openssl rand -hex 32)
                    echo "Generated new API key: $INTERNAL_API_KEY"
                    echo "⚠️  Save this key securely! You'll need it for API requests."
                else
                    INTERNAL_API_KEY=$user_key
                    echo "Using provided API key."
                fi
                echo ""
            fi
            
            # Update the .env file with the actual API key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/your-secure-api-key-here/$INTERNAL_API_KEY/" .env
            else
                # Linux
                sed -i "s/your-secure-api-key-here/$INTERNAL_API_KEY/" .env
            fi
            echo ".env file updated with secure API key"
        else
            echo "Using API key from environment variable."
            # Update the .env file with the environment API key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/your-secure-api-key-here/$INTERNAL_API_KEY/" .env
            else
                # Linux
                sed -i "s/your-secure-api-key-here/$INTERNAL_API_KEY/" .env
            fi
        fi
    else
        echo "Creating .env file..."
        
        # Generate or use existing API key
        if [ -z "${INTERNAL_API_KEY:-}" ]; then
            if [ "$NON_INTERACTIVE" = true ] || [ -n "${CI:-}" ]; then
                # Non-interactive mode: generate key automatically
                INTERNAL_API_KEY=$(openssl rand -hex 32)
                echo "Generated API key: $INTERNAL_API_KEY"
            else
                # Interactive mode: prompt user
                echo ""
                echo "No API key found in environment."
                read -p "Enter API key (press Enter to auto-generate): " user_key
                if [ -z "$user_key" ]; then
                    INTERNAL_API_KEY=$(openssl rand -hex 32)
                    echo "Generated new API key: $INTERNAL_API_KEY"
                    echo "⚠️  Save this key securely! You'll need it for API requests."
                else
                    INTERNAL_API_KEY=$user_key
                    echo "Using provided API key."
                fi
                echo ""
            fi
        else
            echo "Using API key from environment variable."
        fi
        
        cat > .env << EOF
# Application Settings
APP_NAME="Synapse Backend"
ENVIRONMENT=development
LOG_LEVEL=INFO

# Security
INTERNAL_API_KEY=$INTERNAL_API_KEY

# Database
DATABASE_URL=sqlite:///capture.db

# Haystack/Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434
EMBEDDING_MODEL=mxbai-embed-large
GENERATIVE_MODEL=gemma3n:e4b
RERANKER_MODEL=BAAI/bge-reranker-v2-m3

# ChromaDB Configuration
CHROMA_HOST=localhost
CHROMA_PORT=8001
CHROMA_COLLECTION_NAME=capture_v3_docs

# Document Processing
CHUNK_SPLIT_BY=sentence
CHUNK_SPLIT_LENGTH=3
CHUNK_SPLIT_OVERLAP=1
MAX_CONTENT_SIZE=10485760
EOF
        echo ".env file created with secure settings"
    fi
fi

# Get port from environment variable (set by Docker Compose or .env)
PORT=${API_CONTAINER_PORT:-8000}

# Start the server
echo "Starting FastAPI server..."
echo "Server will be available at http://localhost:$PORT"
echo "API docs available at http://localhost:$PORT/docs"
echo "Press Ctrl+C to stop"
echo ""

# Run with Python path set correctly
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port $PORT