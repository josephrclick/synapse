# Manual Testing Instructions

## Setup

1. **Ensure dependencies are installed:**
   ```bash
   cd /home/joe/dev/projects/capture-v3
   source venv/bin/activate
   cd backend
   pip install -r requirements.txt
   pip install -r requirements-dev.txt
   ```

2. **Start the backend server:**
   ```bash
   # In one terminal
   cd /home/joe/dev/projects/capture-v3/backend
   python start_server.py
   ```

3. **Run the new pytest suite:**
   ```bash
   # In another terminal
   cd /home/joe/dev/projects/capture-v3
   source venv/bin/activate
   cd backend
   pytest tests/test_flow.py -v -s
   ```

## Test Options

### Run all tests with debug output:
```bash
pytest tests/test_flow.py -v -s
```

### Run specific tests:
```bash
# Just health check
pytest tests/test_flow.py::test_health -v -s

# Just document flow
pytest tests/test_flow.py::test_document_flow -v -s

# Just error cases
pytest tests/test_flow.py::test_error_cases -v -s
```

### Run tests without debug output:
```bash
pytest tests/test_flow.py -v
```

## What to Expect

With the `-s` flag, you'll see output like:
```
=== TESTING HEALTH ENDPOINT ===
Status: 200
Response: {
  "status": "healthy",
  "backend": "operational",
  ...
}
✓ Health check passed!
```

Without `-s`, you'll just see:
```
tests/test_flow.py::test_health PASSED
```

## Troubleshooting

1. **ModuleNotFoundError**: Make sure you're in the virtual environment and have installed all requirements
2. **Connection refused**: Make sure the server is running (python start_server.py)
3. **403 Forbidden**: Check that your .env file has the correct API_KEY

## Key Differences from Old test_api.py

- No need to start server separately (TestClient handles it)
- Tests run with `pytest` command instead of `python test_api.py`
- Can run individual tests or all at once
- Better integration with CI/CD tools
- Same visual debug output when using `-s` flag