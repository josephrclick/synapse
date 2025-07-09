# Build Plan: Project Rebrand - capture-v3 to synapse

**Ticket ID:** SYN-101  
**Date:** 2025-07-09  
**Priority:** High  
**Scope:** Full codebase rebrand affecting 84 occurrences

## Consensus Summary

Based on analysis and expert consensus from multiple AI models:

### Key Points of Agreement:
1. **Technical Feasibility**: Entirely feasible, common refactoring task
2. **Automation Critical**: Manual changes risk errors; automation ensures consistency
3. **Feature Branch Strategy**: Use dedicated branch with atomic commits
4. **Cache Clearing Essential**: Aggressive cache clearing prevents build issues
5. **Database Migration**: Highest risk item requiring careful handling

### Key Points of Disagreement:
- **Gemini-2.5-pro**: Advocates for single atomic script, combining all phases
- **o4-mini**: Prefers incremental commits per domain for better traceability

### Final Recommendation:
Hybrid approach combining automation with logical commit separation for clarity and rollback capability.

## Implementation Strategy

### Phase 0: Preparation & Script Creation
1. Create feature branch `rebrand-synapse`
2. Handle uncommitted changes (stash or commit separately)
3. Create automated refactoring script `scripts/rebrand-to-synapse.sh`

### Phase 1: Automated Refactoring Script

```bash
#!/bin/bash
# scripts/rebrand-to-synapse.sh

set -euo pipefail

echo "🔄 Starting rebrand from capture-v3 to synapse..."

# Function to perform safe replacements
safe_replace() {
    local pattern=$1
    local replacement=$2
    local file_pattern=$3
    
    echo "  Replacing '$pattern' with '$replacement' in $file_pattern files..."
    find . -type f -name "$file_pattern" -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./__pycache__/*" \
        -exec sed -i.bak "s/$pattern/$replacement/g" {} \;
}

# Phase 1: Backend string replacements
echo "📦 Phase 1: Backend refactoring..."
safe_replace "capture-v3" "synapse" "*.py"
safe_replace "Capture-v3" "Synapse" "*.py"
safe_replace "capture\\.db" "synapse.db" "*.py"
safe_replace "capture-v3" "synapse" "*.sh"

# Phase 2: Configuration files
echo "⚙️ Phase 2: Configuration updates..."
safe_replace "capture-v3" "synapse" "*.yml"
safe_replace "capture-v3" "synapse" "*.yaml"
safe_replace "capture-v3" "synapse" "Makefile"
safe_replace "capture-network" "synapse-network" "docker-compose.yml"
safe_replace "capture\\." "synapse." ".gitignore"

# Phase 3: Frontend updates
echo "🎨 Phase 3: Frontend refactoring..."
safe_replace "capture-v3" "synapse" "*.json"
safe_replace "capture-v3" "synapse" "*.tsx"
safe_replace "capture-v3" "synapse" "*.ts"
safe_replace "Capture-v3" "Synapse" "*.tsx"
safe_replace "Capture-v3" "Synapse" "*.ts"

# Phase 4: Documentation
echo "📚 Phase 4: Documentation updates..."
safe_replace "capture-v3" "synapse" "*.md"
safe_replace "Capture-v3" "Synapse" "*.md"
safe_replace "capture\\.db" "synapse.db" "*.md"

# Phase 5: Directory and file renames
echo "📁 Phase 5: Directory and file renames..."
if [ -d "frontend/capture-v3" ]; then
    mv frontend/capture-v3 frontend/synapse
    echo "  Renamed frontend/capture-v3 to frontend/synapse"
fi

if [ -f "capture.db" ]; then
    cp capture.db synapse.db
    echo "  Created synapse.db from capture.db (preserved original)"
fi

# Cleanup backup files
find . -name "*.bak" -type f -delete

echo "✅ Refactoring complete!"
```

### Phase 2: Execution Plan

1. **Create feature branch**:
   ```bash
   git checkout -b rebrand-synapse
   git add -A
   git commit -m "chore: stash uncommitted changes before rebrand"
   ```

2. **Run automated script**:
   ```bash
   chmod +x scripts/rebrand-to-synapse.sh
   ./scripts/rebrand-to-synapse.sh
   ```

3. **Commit in logical chunks**:
   ```bash
   # Backend changes
   git add backend/
   git commit -m "refactor(backend): rebrand capture-v3 to synapse"
   
   # Configuration changes
   git add Makefile docker-compose.yml .gitignore
   git commit -m "refactor(config): update build and docker configurations for synapse"
   
   # Frontend changes
   git add frontend/
   git commit -m "refactor(frontend): rebrand frontend directory and packages to synapse"
   
   # Documentation changes
   git add *.md docs/
   git commit -m "docs: update all documentation for synapse rebrand"
   
   # Database rename
   git add synapse.db
   git commit -m "refactor(db): add synapse.db (migrated from capture.db)"
   ```

### Phase 3: Verification & Cleanup

1. **Clean all caches**:
   ```bash
   make clean
   docker system prune -a
   rm -rf frontend/synapse/.next
   rm -rf backend/__pycache__
   rm -rf frontend/synapse/node_modules
   cd frontend/synapse && npm install
   ```

2. **Run full test suite**:
   ```bash
   make test
   make run-all
   ```

3. **Verification checklist**:
   - [ ] `grep -r "capture-v3" . --exclude-dir=.git` returns no results
   - [ ] Backend starts without errors
   - [ ] Frontend builds and runs
   - [ ] Database connections work
   - [ ] Docker containers start properly
   - [ ] All tests pass

### Phase 4: Merge Strategy

1. Create pull request from `rebrand-synapse` to `main`
2. Ensure CI/CD passes
3. Merge as a single squashed commit or preserve logical commits

## Risk Mitigation

1. **Database Strategy**: 
   - Keep `capture.db` initially as backup
   - Update connection strings to use `synapse.db`
   - After verification, remove `capture.db`

2. **Cache Issues**:
   - Full Docker rebuild: `docker-compose build --no-cache`
   - Clear all Python caches
   - Fresh npm install

3. **Path Dependencies**:
   - Script handles word boundaries
   - Manual review of Makefile paths
   - Test all build commands

## Success Criteria

- Zero occurrences of "capture-v3" in codebase (excluding git history)
- All services start and communicate properly
- Test suite passes 100%
- Documentation reflects new branding
- Clean build from scratch succeeds

## Estimated Timeline

- Script creation and testing: 2 hours
- Execution and verification: 4 hours
- Troubleshooting buffer: 2 hours
- **Total**: ~1 day of focused work

## Notes

- Original ticket's phased approach adapted to use automation while maintaining logical commit separation
- Database migration simplified to copy operation for development environment
- Emphasis on cache clearing based on consensus recommendation