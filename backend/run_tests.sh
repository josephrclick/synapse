#!/bin/bash
# Quick test runner script

echo "Running Synapse Backend Tests..."
echo "=================================="

# Get the script directory and repo root first
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Check if we're already in a virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    # Always source the venv to ensure we use the right Python/pytest
    echo "Activating virtual environment..."
    if [ -f "$REPO_ROOT/venv/bin/activate" ]; then
        source "$REPO_ROOT/venv/bin/activate"
    else
        echo "Error: Virtual environment not found at $REPO_ROOT/venv"
        echo "Please run 'make setup' or create the virtual environment first."
        exit 1
    fi
else
    echo "Using existing virtual environment: $VIRTUAL_ENV"
fi

# Change to backend directory for running tests
cd "$SCRIPT_DIR"

# Set PYTHONPATH to find backend module
export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"

# Run tests with proper output
echo ""
echo "Running pytest with debug output..."
echo ""
pytest tests/ -v -s "$@"

echo ""
echo "=================================="
echo "Test run complete!"