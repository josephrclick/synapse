# Playwright MCP Notes for Synapse Project

## Research Summary

After comprehensive research and consensus validation, **Microsoft Playwright MCP** is the optimal solution for UI automation and development workflows.

### Why Playwright MCP?
- **Accessibility tree approach** (default) - semantic understanding, fast (~100ms)
- **Vision mode** (optional) - screenshot-based verification when needed
- **Natural language commands** - aligns with Claude's conversational strengths
- **Cross-browser support** - Chromium, Firefox, WebKit

### Installation

```bash
# Recommended installation methods
npx @smithery/cli install @executeautomation/playwright-mcp-server --client claude
# OR
npm install -g @executeautomation/playwright-mcp-server
```

### Configuration

```json
// Standard mode (accessibility tree - fast)
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}

// Vision mode (screenshots - visual)
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--vision"]
    }
  }
}
```

## Quick Cheat Sheet - UI Design Session

### Pre-Session Setup
```bash
make dev  # Start your app
# Verify Playwright MCP shows as "connected" in Claude
```

### Essential Flow Pattern
1. Navigate to page
2. Take "before" screenshot
3. Make changes (in code)
4. Reload page
5. Take "after" screenshot
6. Repeat

### Core Commands

**Navigation & Basic Operations**
- `Navigate to http://localhost:8100`
- `Take screenshot "baseline"`
- `Reload the page`
- `browser_snapshot()` - Get element structure
- `Extract all visible text`

**Responsive Testing**
```
Resize browser to 375, 667    # Mobile
Take screenshot "mobile"
Resize browser to 768, 1024   # Tablet  
Take screenshot "tablet"
Resize browser to 1920, 1080  # Desktop
Take screenshot "desktop"
```

**Interactive States**
```
Hover over button with text "Submit"
Take screenshot "button-hover"
Click the button
Take screenshot "button-active"
```

**Smart Waiting**
```
Wait for text "Loading" to disappear
Wait for element with class "content"
# Avoid fixed waits like "Wait for 2 seconds"
```

### Design Workflow

1. **Baseline**: `Take screenshot "v0"`
2. **Make code change** (in editor)
3. **Refresh**: `Reload the page`
4. **Capture**: `Take screenshot "v1"`
5. **Test**: Click/hover/type interactions
6. **Document**: `Take screenshot "v1-interaction"`
7. **Repeat**

### Pro Tips

**Element Selection (fastest to slowest)**
- `Click element with id "submit-btn"` - Fastest
- `Click element with aria-label "Submit"` - Fast
- `Click element with class "primary-btn"` - Good
- `Click button with text "Submit"` - Slower

**Common Patterns**
```
# Before/After comparison
Take screenshot "original"
# Make CSS changes in code
Reload page
Take screenshot "updated"

# Test all viewports quickly
browser_resize(375, 667)
browser_snapshot()
browser_resize(1920, 1080)
browser_snapshot()

# Document component states
Take screenshot "default"
Hover over component
Take screenshot "hover"
Click component
Take screenshot "active"
```

### Gotchas
- **Can't edit CSS directly** - Change code, then reload
- **Animations interfere** - Wait 0.5-1 second
- **Page not updating?** - Hard reload: `Press Ctrl+Shift+R`
- **Use semantic selectors** for reliability

### Synapse-Specific Patterns

**Chat UI Testing**
```
Type "Test **markdown**" in chat input
Submit
Wait for message in chat history
Take screenshot "markdown-rendering"
```

**Dark Mode Toggle**
```
Click element with aria-label "Toggle theme"
Wait for 0.3 seconds  # Transition
Take screenshot "theme-switched"
```

**Document Upload**
```
Navigate to /ingest
browser_file_upload(["/path/to/test.pdf"])
Wait for text "Upload complete"
Take screenshot "upload-success"
```

## Implementation Timeline

**Phase 1 (Now)**: Continue manual screenshots
**Phase 2 (Week 1-2)**: Install and integrate Playwright MCP
**Phase 3 (Week 3+)**: Add vision mode and advanced features

## Key Benefits
- Semantic understanding via accessibility tree
- 100-200ms operations (10x faster than screenshots)
- Natural language commands
- Reduced ambiguity and false positives
- Industry-standard approach

**Confidence Level: 9/10** based on research and expert consensus