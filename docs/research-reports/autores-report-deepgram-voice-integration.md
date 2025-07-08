# Deepgram Voice Integration Research Report

## Task Overview
Research the simplest, lowest-lift approach to integrate Deepgram cloud voice features for push-to-talk transcription in capture-v3. The goal is to add a voice ingestion element that allows users to push a button, speak, and have their speech transcribed and sent to the database.

## Current Architecture Analysis

### Frontend (Next.js 15)
- Dark mode UI with chat interface
- Document ingestion form at `/ingest`
- Uses server actions for backend communication
- Environment configured for `http://localhost:8101` backend

### Backend (Python/FastAPI)
- Document ingestion endpoint: `POST /api/documents`
- Accepts documents with type, title, content, tags
- SQLite for document storage, ChromaDB for vectors
- Well-defined schema with DocumentCreate model

### Key Integration Points
1. **Frontend**: Add voice capture UI element to ingest page
2. **Backend**: Potentially add voice-specific document type
3. **API**: Existing document ingestion endpoint can be reused

## Deepgram Research Findings

### API Capabilities
- **Real-time streaming transcription**: WebSocket-based live transcription
- **Pre-recorded transcription**: For completed audio files
- **Free tier available**: Sign up at console.deepgram.com
- **Multiple SDKs**: JavaScript (browser/Node.js) and Python

### Key Technical Details
1. **JavaScript SDK Features**:
   - Browser-compatible with direct microphone access
   - WebSocket streaming for real-time transcription
   - Simple integration with MediaStream API
   - Model options: nova-3 (latest), nova-2

2. **Python SDK Features**:
   - REST and WebSocket support
   - Can handle audio streams or files
   - Server-side processing for better security

## Proposed Integration Approaches

### Approach 1: Frontend-Only (Simplest, "Ugly but Working")

**Pros**: 
- Minimal backend changes
- Quick to implement
- No proxy/server modifications needed

**Cons**:
- API key exposed in browser (security risk)
- Limited to browser constraints
- Not production-ready

**Implementation Steps**:
1. Add Deepgram JS SDK to frontend
2. Create push-to-talk component
3. Stream audio directly to Deepgram
4. Submit transcription to existing `/api/documents` endpoint

**Code Structure**:
```javascript
// components/VoiceInput.tsx
const VoiceInput = () => {
  // MediaStream setup
  // Deepgram WebSocket connection
  // Push-to-talk handlers
  // Submit transcription as document
}
```

### Approach 2: Backend Proxy (More Secure, Still Simple)

**Pros**:
- API key secure on backend
- Can add processing/validation
- Production-viable

**Cons**:
- Requires backend endpoint
- Slightly more complex

**Implementation Steps**:
1. Add new FastAPI endpoint for audio streaming
2. Backend proxies to Deepgram API
3. Frontend streams audio to backend
4. Backend returns transcription

### Approach 3: Hybrid Quick Implementation (Recommended)

**The "Bolt-On" Solution**:
1. Use frontend for audio capture only
2. Send audio blob to backend
3. Backend handles Deepgram API call
4. Reuse existing document ingestion flow

**Why This Works Best**:
- Secure API key handling
- Minimal new code
- Leverages existing infrastructure
- Can be ugly but functional quickly

## Implementation Plan (Hybrid Approach)

### Phase 1: Backend Setup (30 minutes)
1. Add `DEEPGRAM_API_KEY` to backend `.env`
2. Add endpoint: `POST /api/transcribe`
3. Use Deepgram Python SDK for transcription
4. Return transcribed text

### Phase 2: Frontend Voice Component (1 hour)
1. Create `VoiceRecorder` component
2. Use MediaRecorder API for push-to-talk
3. Send audio blob to backend
4. Display transcription result

### Phase 3: Integration (30 minutes)
1. Add voice button to ingest page
2. Auto-populate form with transcription
3. Add "voice_note" document type
4. Test end-to-end flow

## Quick Start Code Snippets

### Backend Endpoint (FastAPI)
```python
# backend/main.py
from deepgram import DeepgramClient, PrerecordedOptions
import os

@app.post("/api/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    # Initialize Deepgram
    dg = DeepgramClient(os.getenv("DEEPGRAM_API_KEY"))
    
    # Read audio data
    audio_data = await file.read()
    
    # Transcribe
    response = dg.listen.rest.v("1").transcribe_file(
        audio_data,
        PrerecordedOptions(model="nova-3", smart_format=True)
    )
    
    # Extract transcript
    transcript = response.results.channels[0].alternatives[0].transcript
    
    return {"transcript": transcript}
```

### Frontend Component (React)
```typescript
// components/VoiceRecorder.tsx
export function VoiceRecorder({ onTranscription }) {
  const [isRecording, setIsRecording] = useState(false);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  const startRecording = async () => {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mediaRecorder = new MediaRecorder(stream);
    mediaRecorderRef.current = mediaRecorder;
    
    mediaRecorder.ondataavailable = (e) => {
      chunksRef.current.push(e.data);
    };
    
    mediaRecorder.onstop = async () => {
      const audioBlob = new Blob(chunksRef.current, { type: 'audio/webm' });
      chunksRef.current = [];
      
      // Send to backend
      const formData = new FormData();
      formData.append('file', audioBlob, 'recording.webm');
      
      const response = await fetch('/api/transcribe', {
        method: 'POST',
        body: formData,
      });
      
      const { transcript } = await response.json();
      onTranscription(transcript);
    };
    
    mediaRecorder.start();
    setIsRecording(true);
  };

  const stopRecording = () => {
    mediaRecorderRef.current?.stop();
    setIsRecording(false);
  };

  return (
    <button
      onMouseDown={startRecording}
      onMouseUp={stopRecording}
      className={`${isRecording ? 'bg-red-600' : 'bg-blue-600'} text-white p-4 rounded`}
    >
      {isRecording ? '🎤 Recording...' : '🎤 Push to Talk'}
    </button>
  );
}
```

## Considerations

### Security
- Never expose Deepgram API key in frontend
- Use environment variables for sensitive data
- Consider rate limiting on transcription endpoint

### UX Improvements (Later)
- Visual feedback during recording
- Waveform visualization
- Transcription preview before submission
- Support for multiple recordings

### Performance
- Audio compression before upload
- Chunked streaming for long recordings
- Cache transcriptions to avoid duplicate API calls

## Cost Estimates
- Deepgram offers free tier ($200 credit)
- Nova model: ~$0.0043/minute
- Free tier supports ~46,500 minutes of transcription
- More than sufficient for testing and initial deployment

## Next Steps
1. Get Deepgram API key from console.deepgram.com
2. Implement backend endpoint
3. Create frontend component
4. Test with real voice input
5. Iterate on UX as needed

## Conclusion
The hybrid approach offers the best balance of simplicity, security, and functionality. It can be implemented in under 2 hours and provides a solid foundation for future enhancements. The "ugly but working" requirement is met by keeping the UI minimal and focusing on core functionality.