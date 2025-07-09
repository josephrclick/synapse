#!/bin/bash

# Fix ChromaDB startup issues after fresh clone
# This script addresses ChromaDB v1.0.0+ volume mount path changes
# 
# ChromaDB Breaking Change:
# - v0.5.x and earlier: volume mount at /chroma/chroma
# - v1.0.0 and later: volume mount at /data
# 
# We've pinned to v0.5.23 to maintain stability

echo "🔧 Fixing ChromaDB startup issues..."
echo ""

# 1. Stop all running containers
echo "1. Stopping any running containers..."
docker compose down

# 2. Remove old ChromaDB volumes that might have corrupted data
echo ""
echo "2. Cleaning up old ChromaDB volumes..."
docker volume ls | grep -E "chroma_data|chromadb" | awk '{print $2}' | while read volume; do
    echo "   Removing volume: $volume"
    docker volume rm "$volume" 2>/dev/null || echo "   (already removed or in use)"
done

# 3. Prune any dangling volumes
echo ""
echo "3. Pruning dangling volumes..."
docker volume prune -f

# 4. Pull latest ChromaDB image to ensure we have v1.0.0+
echo ""
echo "4. Pulling latest ChromaDB image..."
docker pull chromadb/chroma:latest

# 5. Rebuild containers with no cache to ensure clean state
echo ""
echo "5. Rebuilding containers..."
docker compose build --no-cache chromadb

echo ""
echo "✅ ChromaDB fixes applied!"
echo ""
echo "Now you can run:"
echo "  make dev        # Start all services"
echo "  make status     # Check service health"
echo ""
echo "Note: ChromaDB is pinned to v0.5.23 which uses /chroma/chroma mount path"
echo "      This prevents breaking changes from newer versions."