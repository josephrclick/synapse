# Dependency Update Report - July 12, 2025

## Issue Summary
The chat feature was returning HTTP 500 errors due to incompatible dependency versions in the backend Python requirements.

## Root Causes
1. **Mismatched requirements files**: The `requirements.txt` file was out of sync with `requirements.in`
2. **ChromaDB API compatibility**: Version incompatibilities between `chroma-haystack` and `chromadb`
3. **NumPy version conflict**: ChromaDB 0.4.x requires NumPy 1.x but NumPy 2.x was being installed

## Changes Made

### 1. ChromaDB and Integration Versions
**Before:**
```
chroma-haystack==3.3.0
chromadb==1.0.15
```

**After:**
```
chroma-haystack==0.15.0
chromadb==0.4.19
```

**Reason**: chroma-haystack 0.15.0 is compatible with ChromaDB 0.4.x series and matches the ChromaDB container version (0.4.24).

### 2. NumPy Version Constraint
**Added to requirements.in:**
```
# NumPy - Pin to 1.x for ChromaDB 0.4.x compatibility
numpy<2.0.0
```

**Result**: `numpy==1.26.4` is now installed instead of numpy 2.x

### 3. Code Changes
Modified `backend/pipelines.py` to use the correct ChromaDocumentStore initialization:
```python
# Before: Tried various parameter combinations that failed
document_store = ChromaDocumentStore(
    collection_name=settings.chroma_collection_name,
    host=settings.chroma_host,
    port=settings.chroma_port
)

# After: Using environment variables and persist_path=None
os.environ["CHROMA_SERVER_HOST"] = settings.chroma_host
os.environ["CHROMA_SERVER_HTTP_PORT"] = str(settings.chroma_port)

document_store = ChromaDocumentStore(
    collection_name=settings.chroma_collection_name,
    persist_path=None  # Use remote ChromaDB instance
)
```

## Impact
- Chat endpoint now returns 200 OK instead of 500 errors
- Successfully connects to ChromaDB vector database
- RAG pipeline functions correctly
- Response time ~17 seconds for queries (expected for local LLM inference)

## Lessons Learned
1. Always regenerate `requirements.txt` from `requirements.in` when making dependency changes
2. Version compatibility between integrations (like chroma-haystack) and their underlying libraries (chromadb) is critical
3. Major version changes in dependencies (like NumPy 1.x to 2.x) can break compatibility with other packages
4. Different versions of libraries may have different API signatures for initialization

## Next Steps
- Monitor for any other dependency conflicts
- Consider pinning more specific versions in requirements.in to prevent future compatibility issues
- Document the correct dependency versions in the project documentation