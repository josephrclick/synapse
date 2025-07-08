# How to Run the New Test Suite

## Quick Test (Without Full Dependencies)

To verify pytest is working without needing all backend dependencies:

```bash
cd /home/joe/dev/projects/capture-v3/backend
# Temporarily move conftest to avoid import errors
mv tests/conftest.py tests/conftest.py.tmp
# Run the minimal test
python -m pytest tests/test_minimal.py -v -s
# Restore conftest
mv tests/conftest.py.tmp tests/conftest.py
```

## Full Test Suite (Requires Dependencies)

### Option 1: Using Existing Virtual Environment

```bash
# From the capture-v3 directory
cd /home/joe/dev/projects/capture-v3
source venv/bin/activate

# Verify you're in venv (should show venv path)
which python

# Install dependencies if not already done
cd backend
pip install -r requirements.txt

# Run tests
pytest tests/test_flow.py -v -s
```

### Option 2: Start Fresh in Backend Directory

```bash
cd /home/joe/dev/projects/capture-v3/backend

# Create new venv
python -m venv test_venv
source test_venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Run tests
pytest tests/test_flow.py -v -s
```

## Test Commands

```bash
# Run all tests with debug output
pytest tests/test_flow.py -v -s

# Run specific test
pytest tests/test_flow.py::test_health -v -s

# Run without debug output
pytest tests/test_flow.py -v

# Run with coverage
pytest tests/test_flow.py --cov=. --cov-report=html
```

## Current Issue

The main blocker is that the haystack-ai package and other dependencies need to be installed. The test framework is ready and will work once dependencies are resolved.

## What the Tests Do

1. **test_health** - Checks the /health endpoint
2. **test_document_flow** - Creates a document and polls for processing status
3. **test_chat_flow** - Tests the RAG chat functionality
4. **test_document_list** - Tests document listing with pagination
5. **test_error_cases** - Tests error handling (missing API key, invalid data, etc.)

Each test shows clear visual output:
```
=== TESTING HEALTH ENDPOINT ===
Status: 200
Response: {...}
✓ Health check passed!
```