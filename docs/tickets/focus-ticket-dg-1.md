# Build Plan: Deepgram JavaScript SDK PoC Implementation

**Project:** Synapse (Synapse)  
**Task ID:** dg-1  
**Created:** 2025-07-08  
**Priority:** URGENT (Interview Prep)

## Executive Summary

Implementing a push-to-talk voice transcription feature using Deepgram's JavaScript SDK as a learning exercise for interview preparation. This is a client-side only proof-of-concept with intentionally relaxed security constraints.

## Consensus Summary

Based on expert analysis from O3, O3-Pro, and GPT-4.1:

### Key Agreements
- **Technical Feasibility:** ✅ Approach is sound for a PoC
- **Implementation Time:** 2-3 hours including error handling
- **Complexity:** ~150 LOC for core functionality
- **Security Trade-off:** API key exposure acceptable for learning exercise

### Critical Improvements (from consensus)
1. Use `pointerdown/pointerup` instead of `mousedown/mouseup` (cross-device support)
2. Lower MediaRecorder timeslice to 250-500ms (better perceived latency)
3. Implement proper cleanup with `useEffect` (prevent memory leaks)
4. Add browser feature detection (avoid runtime crashes)
5. Enable `punctuate:true, utterances:true` in Deepgram config
6. Consider custom hook pattern for cleaner code

## Technical Architecture

### Component Structure
```
frontend/synapse/
├── app/
│   ├── components/
│   │   └── voice/
│   │       └── DeepgramPocButton.tsx  # Main component
│   └── hooks/
│       └── useDeepgramLive.ts         # Custom hook (optional)
```

### Key Technologies
- **Next.js 15** with App Router
- **Deepgram JavaScript SDK** (@deepgram/sdk)
- **MediaRecorder API** for audio capture
- **WebSocket** for real-time streaming
- **React Hooks** (useState, useRef, useEffect)

## Implementation Details

### 1. Browser Compatibility Checks
```typescript
const isSupported = 
  typeof window !== 'undefined' &&
  navigator.mediaDevices?.getUserMedia &&
  window.MediaRecorder;
```

### 2. MediaRecorder Configuration
- **Format:** audio/webm (default, works with Deepgram)
- **Timeslice:** 250ms (optimal balance for latency)
- **Audio constraints:** `{ audio: true }`

### 3. Deepgram Configuration
```typescript
const connection = deepgram.listen.live({
  model: "nova-2",
  language: "en-US",
  smart_format: true,
  punctuate: true,
  utterances: true,
  interim_results: true,
  utterance_end_ms: 1000,
  vad_events: true,
  endpointing: 300
});
```

### 4. Event Handling
- **Pointer Events:** Better than mouse for touch devices
- **Connection Events:** open, close, error, transcript
- **Transcript Processing:** Check for `is_final` and `speech_final`

### 5. Cleanup Strategy
```typescript
useEffect(() => {
  return () => {
    // Stop MediaRecorder
    // Close WebSocket connection
    // Stop media stream tracks
  };
}, []);
```

## Implementation Steps

### Phase 1: Setup (15 mins)
1. Install Deepgram SDK: `npm install @deepgram/sdk`
2. Add API key to `.env.local`:
   ```
   NEXT_PUBLIC_DEEPGRAM_API_KEY=your-key-here
   ```
3. Create voice component directory

### Phase 2: Core Component (60 mins)
1. Create `DeepgramPocButton.tsx` with 'use client' directive
2. Implement browser feature detection
3. Set up state management (isRecording, transcript)
4. Create refs for MediaRecorder and connection

### Phase 3: Audio Pipeline (45 mins)
1. Implement pointer event handlers
2. Set up MediaRecorder with 250ms timeslice
3. Create Deepgram connection with optimized settings
4. Wire up audio chunk streaming

### Phase 4: UI & Cleanup (30 mins)
1. Style push-to-talk button (dark mode compatible)
2. Display transcript in `<p>` tag
3. Add proper cleanup in useEffect
4. Basic error handling (permissions, connection)

### Phase 5: Integration (30 mins)
1. Import component in `page.tsx`
2. Position below existing chat interface
3. Test functionality
4. Add warning comments about API key exposure

## Risk Mitigation

### Identified Risks
1. **API Key Exposure:** Document as intentional for PoC
2. **Memory Leaks:** Proper cleanup implementation
3. **Browser Support:** Feature detection gates
4. **Rapid Clicks:** State management to prevent multiple connections
5. **Cost Overrun:** Monitor Deepgram usage during testing

### Error Scenarios to Handle
- Microphone permission denied
- WebSocket connection failure
- Network interruptions
- Browser incompatibility
- Rapid button clicks

## Success Criteria

- [ ] Push-to-talk button visible in UI
- [ ] Clicking and holding activates microphone
- [ ] Audio streams to Deepgram while held
- [ ] Final transcript displays on release
- [ ] No memory leaks on navigation
- [ ] Works on Chrome, Edge, Firefox
- [ ] Clear warnings about API key exposure

## Future Considerations

For production migration:
1. Move API key to backend
2. Implement server-side proxy for WebSocket
3. Add comprehensive error handling
4. Improve UI/UX with loading states
5. Add transcript history
6. Support for multiple languages
7. Implement proper authentication

## Code Quality Guidelines

- Use TypeScript for type safety
- Follow existing project conventions
- Add JSDoc comments for main functions
- Include "NOT FOR PRODUCTION" warnings
- Keep component under 200 LOC
- Extract to custom hook if complexity grows

## Testing Plan

1. **Happy Path:** Hold button → speak → release → see transcript
2. **Permission Denied:** Handle gracefully with user message
3. **Rapid Clicks:** Ensure single connection at a time
4. **Navigation:** Verify cleanup on route change
5. **Network Issues:** Test connection failures

## Documentation

Add to CLAUDE.md after implementation:
- Component location and purpose
- Environment variable requirement
- Security warning about API key
- Known limitations (Safari, etc.)

---

**Ready to implement!** This plan incorporates all consensus feedback and provides a clear path to a working PoC in approximately 3 hours.