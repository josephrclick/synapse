# System-Wide Deepgram STT MVP - Simplified Build Plan

**Ticket ID**: SYSTEM-DG-1  
**Priority**: High  
**Type**: MVP / Proof of Concept  
**Estimated Effort**: 3-5 days

## Summary

Build the simplest possible Node.js CLI tool that captures voice via hotkey and injects transcribed text into the active window on Ubuntu 24.04 (Wayland). This MVP validates the concept before any complex implementation.

## Core Principle: KISS (Keep It Simple, Stupid)

### What We're Building
- A Node.js script that runs in terminal
- Press a hotkey → speak → text appears in active window
- No GUI, no tray, no fancy features
- Ubuntu/Wayland only

### What We're NOT Building (Yet)
- ❌ Electron app
- ❌ Cross-platform support
- ❌ System tray UI
- ❌ Settings interface
- ❌ Multiple recording modes
- ❌ Error recovery

## Technical Approach

### 1. Simple Architecture
```
User presses hotkey → Node.js captures audio → Deepgram transcribes → wtype injects text
```

### 2. Minimal Dependencies
```json
{
  "dependencies": {
    "@deepgram/sdk": "^3.x",
    "node-record-lpcm16": "^1.0.1",
    "dotenv": "^16.0.0"
  }
}
```

### 3. Core Implementation (index.js)
```javascript
// Pseudo-code structure
const record = require('node-record-lpcm16');
const { Deepgram } = require('@deepgram/sdk');
const { exec } = require('child_process');

// Start recording when called
function startRecording() {
  const recording = record.record({ sampleRate: 16000 });
  const deepgram = new Deepgram(process.env.DEEPGRAM_API_KEY);
  
  // Stream to Deepgram
  const connection = await deepgram.listen.live({
    model: 'nova-2',
    language: 'en-US'
  });
  
  // On transcript, inject text
  connection.on('transcript', (data) => {
    const text = data.channel.alternatives[0].transcript;
    exec(`wtype "${text}"`);
  });
  
  recording.stream().pipe(connection);
}
```

## MVP Implementation Steps

### Day 1: Core Functionality
1. Set up Node.js project with package.json
2. Copy Deepgram API key from existing `.env`
3. Test audio recording with `node-record-lpcm16`
4. Connect to Deepgram and log transcripts to console

### Day 2: Text Injection
1. Install `wtype`: `sudo apt install wtype`
2. Test `wtype` command manually
3. Integrate text injection on transcript
4. Add clipboard fallback with `wl-copy`

### Day 3: Hotkey Integration
1. Create simple CLI: `node index.js --toggle`
2. Write GNOME hotkey setup instructions
3. Test end-to-end flow
4. Document setup process

## Wayland-Specific Approach

Since we're on Wayland:
- **Text injection**: `wtype` (primary) or `wl-copy` (fallback)
- **Hotkey**: User configures in GNOME Settings → Keyboard → Custom Shortcuts
- **No X11 dependencies**: Future-proof, secure

## Simplified Setup Instructions

```bash
# 1. Install dependencies
sudo apt install wtype wl-clipboard sox
npm install

# 2. Set environment
echo "DEEPGRAM_API_KEY=your-key-here" > .env

# 3. Test recording
node index.js --test-audio

# 4. Configure hotkey in GNOME
# Settings → Keyboard → Custom Shortcuts
# Name: "Voice to Text"
# Command: /path/to/node /path/to/index.js --toggle
# Shortcut: Ctrl+Alt+Space

# 5. Use it!
# Press hotkey → speak → text appears
```

## Success Criteria for MVP

1. ✅ Can trigger recording via GNOME hotkey
2. ✅ Transcribes speech within 1-2 seconds
3. ✅ Text appears in active window (Terminal, VS Code, Browser)
4. ✅ Falls back to clipboard when injection fails
5. ✅ Clear setup documentation

## What Comes After MVP

Once we validate this works and is useful:
1. Add visual/audio feedback
2. Implement proper start/stop mechanism
3. Consider Electron wrapper for better UX
4. Add configuration options
5. Expand platform support

## Key Decisions Made

1. **Wayland-first**: No X11 fallback, embrace the future
2. **CLI endpoint**: Simpler than global hotkey libraries
3. **wtype**: Best tool for Wayland text injection
4. **No GUI**: Validate concept first, polish later
5. **Single command**: Just `--toggle` to start/stop

## Files to Create

```
synapse-stt-mvp/
├── index.js          # Everything in one file for MVP
├── package.json      # Minimal dependencies
├── .env              # DEEPGRAM_API_KEY
├── README.md         # Setup instructions
└── test-audio.js     # Simple audio test script
```

## Risk Mitigation

- **If wtype fails**: Use clipboard with notification
- **If audio fails**: Clear error message with troubleshooting
- **If hotkey confuses users**: Provide video tutorial link
- **If performance is slow**: Log timing, optimize in v2

## Bottom Line

**Ship something that works in 3 days**, not something perfect in 3 weeks. Once we prove the concept adds value, we can invest in the full implementation.