# Deepgram Push-to-Talk Integration Guide for Synapse

## Overview

This guide provides the simplest, quickest way to bolt on push-to-talk voice transcription to your Synapse project using Deepgram's cloud API. This is designed for rapid prototyping and testing - not production-ready code.

## Quick Start Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Browser Mic   │────▶│  Deepgram Live  │────▶│  Backend API    │
│   (Push-to-Talk)│     │   WebSocket     │     │   (FastAPI)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Prerequisites

1. **Deepgram API Key**: Sign up at [console.deepgram.com](https://console.deepgram.com) for a free API key
2. **HTTPS**: Microphone access requires HTTPS (localhost is fine for dev)

## Minimal Implementation

### Step 1: Install Deepgram SDK

```bash
cd frontend/synapse
npm install @deepgram/sdk
```

### Step 2: Create Voice Ingestion Component

Create `frontend/synapse/app/components/voice/VoiceCapture.tsx`:

```tsx
'use client';

import { useState, useRef, useEffect } from 'react';
import { createClient, LiveTranscriptionEvents } from '@deepgram/sdk';
import type { LiveClient } from '@deepgram/sdk';

interface VoiceCaptureProps {
  onTranscript: (text: string) => void;
  apiKey: string;
}

export function VoiceCapture({ onTranscript, apiKey }: VoiceCaptureProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [status, setStatus] = useState('Ready');
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const deepgramRef = useRef<LiveClient | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (deepgramRef.current) {
        deepgramRef.current.requestClose();
      }
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  const startRecording = async () => {
    try {
      setStatus('Requesting microphone...');
      
      // Get microphone access
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          sampleRate: 16000,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
        } 
      });
      streamRef.current = stream;

      // Initialize Deepgram
      const deepgram = createClient(apiKey);
      const connection = deepgram.listen.live({
        model: 'nova-2',
        language: 'en-US',
        smart_format: true,
        interim_results: true,
        utterance_end_ms: 1000,
        vad_events: true,
        endpointing: 300,
      });

      deepgramRef.current = connection;

      // Set up Deepgram event handlers
      connection.on(LiveTranscriptionEvents.Open, () => {
        setStatus('Connected to Deepgram');
        
        // Set up MediaRecorder
        const mediaRecorder = new MediaRecorder(stream, {
          mimeType: 'audio/webm;codecs=opus'
        });
        
        mediaRecorderRef.current = mediaRecorder;

        // Send audio chunks to Deepgram
        mediaRecorder.ondataavailable = async (event) => {
          if (event.data.size > 0 && connection.getReadyState() === 1) {
            const buffer = await event.data.arrayBuffer();
            connection.send(new Uint8Array(buffer));
          }
        };

        // Start recording with 100ms chunks
        mediaRecorder.start(100);
        setIsRecording(true);
        setStatus('Recording...');
      });

      connection.on(LiveTranscriptionEvents.Transcript, (data) => {
        const transcript = data.channel.alternatives[0].transcript;
        
        // Only process final transcripts
        if (transcript && data.is_final && data.speech_final) {
          console.log('Final transcript:', transcript);
          onTranscript(transcript);
        }
      });

      connection.on(LiveTranscriptionEvents.Error, (err) => {
        console.error('Deepgram error:', err);
        setStatus('Error: ' + err.message);
        stopRecording();
      });

      connection.on(LiveTranscriptionEvents.Close, () => {
        setStatus('Connection closed');
      });

    } catch (error) {
      console.error('Failed to start recording:', error);
      setStatus('Error: ' + (error as Error).message);
    }
  };

  const stopRecording = () => {
    // Stop MediaRecorder
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }

    // Close Deepgram connection
    if (deepgramRef.current) {
      deepgramRef.current.requestClose();
      deepgramRef.current = null;
    }

    // Stop media stream
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    setIsRecording(false);
    setStatus('Ready');
  };

  return (
    <div className="flex flex-col items-center gap-4 p-6 bg-zinc-900 rounded-lg border border-zinc-800">
      <h3 className="text-xl font-semibold text-zinc-100">Voice Input</h3>
      
      <button
        onMouseDown={startRecording}
        onMouseUp={stopRecording}
        onMouseLeave={stopRecording}
        disabled={isRecording && false}
        className={`
          px-8 py-4 rounded-full font-medium transition-all
          ${isRecording 
            ? 'bg-red-600 hover:bg-red-700 text-white scale-110' 
            : 'bg-blue-600 hover:bg-blue-700 text-white'
          }
        `}
      >
        {isRecording ? '🎤 Recording...' : '🎙️ Push to Talk'}
      </button>
      
      <p className="text-sm text-zinc-500">{status}</p>
    </div>
  );
}
```

### Step 3: Create Voice Ingestion Page

Create `frontend/synapse/app/voice/page.tsx`:

```tsx
'use client';

import { useState } from 'react';
import { VoiceCapture } from '@/app/components/voice/VoiceCapture';

// WARNING: Never expose API keys in production!
// This is only for quick testing. Move to backend in production.
const DEEPGRAM_API_KEY = process.env.NEXT_PUBLIC_DEEPGRAM_API_KEY || '';

export default function VoiceIngestionPage() {
  const [transcripts, setTranscripts] = useState<string[]>([]);
  const [isSaving, setIsSaving] = useState(false);

  const handleTranscript = (text: string) => {
    setTranscripts(prev => [...prev, text]);
  };

  const saveToDatabase = async () => {
    if (transcripts.length === 0) return;

    setIsSaving(true);
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/api/documents`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': process.env.NEXT_PUBLIC_BACKEND_API_KEY || '',
        },
        body: JSON.stringify({
          title: `Voice Note - ${new Date().toLocaleString()}`,
          content: transcripts.join('\n\n'),
          doc_type: 'voice_transcript',
          source: 'voice_input',
          tags: ['voice', 'transcript'],
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to save transcript');
      }

      // Clear transcripts after successful save
      setTranscripts([]);
      alert('Voice note saved successfully!');
    } catch (error) {
      console.error('Error saving transcript:', error);
      alert('Failed to save voice note');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-950 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-zinc-100 mb-8">Voice Ingestion</h1>
        
        <VoiceCapture 
          apiKey={DEEPGRAM_API_KEY}
          onTranscript={handleTranscript}
        />

        {transcripts.length > 0 && (
          <div className="mt-8 space-y-4">
            <div className="bg-zinc-900 rounded-lg border border-zinc-800 p-6">
              <h2 className="text-xl font-semibold text-zinc-100 mb-4">
                Captured Transcripts
              </h2>
              <div className="space-y-2">
                {transcripts.map((text, index) => (
                  <p key={index} className="text-zinc-300 p-3 bg-zinc-800 rounded">
                    {text}
                  </p>
                ))}
              </div>
            </div>

            <button
              onClick={saveToDatabase}
              disabled={isSaving}
              className="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium disabled:opacity-50"
            >
              {isSaving ? 'Saving...' : 'Save to Knowledge Base'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
```

### Step 4: Add Environment Variable

Add to `frontend/synapse/.env.local`:

```bash
# WARNING: Only for testing! Move to backend proxy in production
NEXT_PUBLIC_DEEPGRAM_API_KEY=your-deepgram-api-key-here
```

### Step 5: Add Navigation Link

Update your main navigation to include the voice ingestion page. In `frontend/synapse/app/page.tsx` or wherever your nav is:

```tsx
<Link 
  href="/voice" 
  className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg"
>
  🎤 Voice Input
</Link>
```

## Usage

1. Navigate to `/voice` in your app
2. Click and hold "Push to Talk" button
3. Speak your notes/thoughts
4. Release to stop recording
5. Review transcripts
6. Click "Save to Knowledge Base" to store in your system

## Security Considerations

⚠️ **This implementation has serious security issues for production:**

1. **API Key Exposure**: The Deepgram API key is exposed in the browser. In production, you should:
   - Create a backend proxy endpoint
   - Handle Deepgram authentication server-side
   - Use your existing API authentication

2. **CORS**: You may need to configure CORS for WebSocket connections

## Production-Ready Implementation

For production, create a backend proxy:

```python
# backend/voice_proxy.py
from fastapi import WebSocket, Depends
from deepgram import Deepgram
import asyncio
import json

@app.websocket("/api/voice/stream")
async def voice_stream(
    websocket: WebSocket,
    api_key: str = Depends(verify_api_key)
):
    await websocket.accept()
    
    # Initialize Deepgram with server-side key
    dg_client = Deepgram(settings.DEEPGRAM_API_KEY)
    
    try:
        # Create live transcription
        socket = await dg_client.transcription.live({
            'punctuate': True,
            'model': 'nova-2',
            'language': 'en-US',
        })
        
        # Forward audio from client to Deepgram
        async def forward_audio():
            while True:
                data = await websocket.receive_bytes()
                socket.send(data)
        
        # Forward transcripts from Deepgram to client
        async def forward_transcripts():
            while True:
                msg = await socket.receive()
                await websocket.send_text(msg)
        
        await asyncio.gather(forward_audio(), forward_transcripts())
        
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()
```

## Advanced Features

### 1. Continuous Recording Mode
Instead of push-to-talk, implement toggle recording with visual feedback.

### 2. Voice Commands
Add command detection for hands-free operation:
- "Start recording"
- "Stop recording"
- "Save note"
- "Clear transcript"

### 3. Real-time Streaming to Chat
Stream transcripts directly to your chat interface for immediate RAG queries.

### 4. Audio Visualization
Add waveform or volume meter for visual feedback during recording.

## Troubleshooting

1. **Microphone Permission Denied**
   - Ensure HTTPS (or localhost)
   - Check browser permissions

2. **No Audio Received**
   - Check browser console for errors
   - Verify microphone is working
   - Try different audio format settings

3. **Transcription Delays**
   - Normal latency is 200-500ms
   - Check network connection
   - Consider using interim results for faster feedback

## Next Steps

1. **Implement backend proxy** for security
2. **Add error recovery** and retry logic
3. **Implement audio preprocessing** for better quality
4. **Add multi-language support** 
5. **Create mobile-friendly UI** with larger touch targets
6. **Add voice activity detection** for auto-start/stop

## Deepgram Model Options

- `nova-2`: Best accuracy (recommended)
- `nova-2-medical`: Medical terminology
- `nova-2-phonecall`: Optimized for phone audio
- `enhanced`: Legacy model
- `base`: Fastest, lower accuracy

## Cost Considerations

Deepgram pricing (as of 2024):
- Pay-as-you-go: ~$0.0125/minute
- Growth plan: ~$0.0080/minute
- Free tier: $200 credit

For testing, the free tier should last several hours of continuous use.

## References

- [Deepgram JavaScript SDK](https://github.com/deepgram/deepgram-js-sdk)
- [Deepgram Live Streaming Docs](https://developers.deepgram.com/docs/live-streaming-audio)
- [WebRTC MediaRecorder API](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder)