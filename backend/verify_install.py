#!/usr/bin/env python3
"""Verify all dependencies installed correctly"""

print("Checking core dependencies...")

# Core API
import fastapi
import uvicorn
import pydantic
print("✅ API framework OK")

# Haystack
import haystack
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack_integrations.components.embedders.ollama import OllamaDocumentEmbedder
print(f"✅ Haystack {haystack.__version__} OK")

# PostgreSQL
import psycopg
import asyncpg
print("✅ PostgreSQL drivers OK")

# ML/NLP
import numpy
import transformers
import nltk
import sklearn
print(f"✅ ML libraries OK (numpy {numpy.__version__})")

# Warnings
if numpy.__version__.startswith("2."):
    print("⚠️  WARNING: NumPy 2.x detected!")

print("\n🎉 All dependencies installed successfully!")
