"""
Minimal pytest fixtures for testing the Synapse API.
Provides TestClient and API headers for all tests.
"""
import os
import sys

# Add parent of backend directory to path so we can import backend as a package
backend_parent = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, backend_parent)

import pytest
from fastapi.testclient import TestClient

# Import as package to handle relative imports in main.py
from backend.main import app
from backend.config import settings


@pytest.fixture
def client():
    """Test client for FastAPI app."""
    # Create client with the app directly - TestClient handles transport internally
    with TestClient(app) as c:
        yield c


@pytest.fixture
def headers():
    """API headers with test API key."""
    return {"X-API-Key": settings.internal_api_key}