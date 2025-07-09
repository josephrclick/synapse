#!/bin/bash
# scripts/rebrand-to-synapse.sh
# Automated script to rebrand synapse to synapse

set -euo pipefail

echo "🔄 Starting rebrand from synapse to synapse..."
echo "================================================"

# Function to perform safe replacements
safe_replace() {
    local pattern=$1
    local replacement=$2
    local file_pattern=$3
    
    echo "  Replacing '$pattern' with '$replacement' in $file_pattern files..."
    find . -type f -name "$file_pattern" \
        -not -path "./node_modules/*" \
        -not -path "./.git/*" \
        -not -path "./__pycache__/*" \
        -not -path "./venv/*" \
        -not -path "./.next/*" \
        -not -path "./backend/venv/*" \
        -not -path "./frontend/*/node_modules/*" \
        -exec sed -i.bak "s/$pattern/$replacement/g" {} \;
}

# Phase 1: Backend string replacements
echo ""
echo "📦 Phase 1: Backend refactoring..."
echo "--------------------------------"
safe_replace "synapse" "synapse" "*.py"
safe_replace "Synapse" "Synapse" "*.py"
safe_replace "capture\\.db" "synapse.db" "*.py"
safe_replace "synapse" "synapse" "*.sh"
safe_replace "Synapse" "Synapse" "*.sh"

# Phase 2: Configuration files
echo ""
echo "⚙️  Phase 2: Configuration updates..."
echo "-----------------------------------"
safe_replace "synapse" "synapse" "*.yml"
safe_replace "synapse" "synapse" "*.yaml"
safe_replace "synapse" "synapse" "Makefile"
safe_replace "capture-network" "synapse-network" "docker-compose.yml"
safe_replace "capture\\." "synapse." ".gitignore"

# Phase 3: Frontend updates
echo ""
echo "🎨 Phase 3: Frontend refactoring..."
echo "---------------------------------"
safe_replace "synapse" "synapse" "*.json"
safe_replace "synapse" "synapse" "*.tsx"
safe_replace "synapse" "synapse" "*.ts"
safe_replace "synapse" "synapse" "*.jsx"
safe_replace "synapse" "synapse" "*.js"
safe_replace "Synapse" "Synapse" "*.tsx"
safe_replace "Synapse" "Synapse" "*.ts"
safe_replace "Synapse" "Synapse" "*.jsx"
safe_replace "Synapse" "Synapse" "*.js"

# Phase 4: Documentation
echo ""
echo "📚 Phase 4: Documentation updates..."
echo "----------------------------------"
safe_replace "synapse" "synapse" "*.md"
safe_replace "Synapse" "Synapse" "*.md"
safe_replace "capture\\.db" "synapse.db" "*.md"
safe_replace "/synapse/" "/synapse/" "*.md"

# Phase 5: Directory and file renames
echo ""
echo "📁 Phase 5: Directory and file renames..."
echo "---------------------------------------"

# Rename frontend directory
if [ -d "frontend/synapse" ]; then
    mv frontend/synapse frontend/synapse
    echo "  ✓ Renamed frontend/synapse to frontend/synapse"
else
    echo "  ⚠️  Directory frontend/synapse not found"
fi

# Handle database file
if [ -f "capture.db" ]; then
    cp capture.db synapse.db
    echo "  ✓ Created synapse.db from capture.db (preserved original)"
else
    echo "  ⚠️  Database file capture.db not found"
fi

# Phase 6: Cleanup backup files
echo ""
echo "🧹 Phase 6: Cleaning up backup files..."
echo "-------------------------------------"
find . -name "*.bak" -type f -delete
echo "  ✓ Removed all .bak files"

echo ""
echo "✅ Refactoring complete!"
echo ""
echo "Next steps:"
echo "1. Review changes with 'git diff'"
echo "2. Run tests with 'make test'"
echo "3. Test the application with 'make run-all'"
echo "4. Commit changes in logical chunks"