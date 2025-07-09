'use client';

import { useState, useRef, useEffect } from 'react';
import { createClient, LiveTranscriptionEvents, LiveClient } from '@deepgram/sdk';

/**
 * DeepgramPocButton - Push-to-talk voice transcription component
 * 
 * WARNING: This is a proof-of-concept for learning purposes only!
 * The API key is exposed in the browser - DO NOT USE IN PRODUCTION!
 * 
 * For production use:
 * - Move API key to backend
 * - Implement server-side WebSocket proxy
 * - Add comprehensive error handling
 */
export default function DeepgramPocButton() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSupported, setIsSupported] = useState(true);

  // Refs to hold our instances
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const connectionRef = useRef<LiveClient | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const isFinalsRef = useRef<string[]>([]);

  // Check browser support on mount
  useEffect(() => {
    const checkSupport = 
      typeof window !== 'undefined' &&
      navigator.mediaDevices?.getUserMedia &&
      window.MediaRecorder;
    
    setIsSupported(!!checkSupport);
    
    if (!checkSupport) {
      setError('Your browser does not support audio recording');
    }
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      // Clean up any active recording
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
      }
      
      // Stop all tracks
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
      
      // Close WebSocket connection
      if (connectionRef.current) {
        connectionRef.current.requestClose();
      }
    };
  }, []);

  const startRecording = async () => {
    try {
      setError(null);
      setTranscript('');
      isFinalsRef.current = [];

      // Get microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      // Initialize Deepgram client
      const apiKey = process.env.NEXT_PUBLIC_DEEPGRAM_API_KEY;
      if (!apiKey) {
        throw new Error('Deepgram API key not found in environment variables');
      }

      const deepgram = createClient(apiKey);
      
      // Create live transcription connection with optimized settings
      const connection = deepgram.listen.live({
        model: 'nova-2',
        language: 'en-US',
        smart_format: true,
        punctuate: true,
        utterances: true,
        interim_results: true,
        utterance_end_ms: 1000,
        vad_events: true,
        endpointing: 300,
      });

      connectionRef.current = connection;

      // Set up connection event handlers
      connection.on(LiveTranscriptionEvents.Open, () => {
        console.log('Deepgram connection opened');
        
        // Create MediaRecorder with browser-compatible settings
        // Try different MIME types based on browser support
        const mimeTypes = [
          'audio/webm;codecs=opus',
          'audio/webm',
          'audio/ogg;codecs=opus',
          'audio/mp4',
        ];
        
        let mediaRecorder: MediaRecorder | null = null;
        let selectedMimeType = '';
        
        // Find a supported MIME type
        for (const mimeType of mimeTypes) {
          if (MediaRecorder.isTypeSupported(mimeType)) {
            selectedMimeType = mimeType;
            break;
          }
        }
        
        try {
          if (selectedMimeType) {
            mediaRecorder = new MediaRecorder(stream, {
              mimeType: selectedMimeType,
            });
          } else {
            // Fallback: let browser choose default
            mediaRecorder = new MediaRecorder(stream);
          }
          console.log('MediaRecorder created with MIME type:', selectedMimeType || 'browser default');
        } catch (e) {
          console.error('MediaRecorder creation failed:', e);
          throw new Error('Your browser does not support audio recording');
        }
        
        mediaRecorderRef.current = mediaRecorder;

        // Send audio chunks to Deepgram
        mediaRecorder.ondataavailable = (event) => {
          if (event.data.size > 0 && connection.getReadyState() === 1) {
            connection.send(event.data);
          }
        };

        // Start recording with 250ms chunks for low latency
        mediaRecorder.start(250);
        setIsRecording(true);
      });

      // Handle transcription results
      connection.on(LiveTranscriptionEvents.Transcript, (data) => {
        const sentence = data.channel.alternatives[0].transcript;
        
        // Ignore empty transcripts
        if (sentence.length === 0) {
          return;
        }

        if (data.is_final) {
          // Collect final transcripts
          isFinalsRef.current.push(sentence);
          
          // Speech final means end of utterance detected
          if (data.speech_final) {
            const utterance = isFinalsRef.current.join(' ');
            setTranscript(prev => prev ? `${prev} ${utterance}` : utterance);
            isFinalsRef.current = [];
          }
        }
      });

      // Handle utterance end (backup for speech_final)
      connection.on(LiveTranscriptionEvents.UtteranceEnd, () => {
        if (isFinalsRef.current.length > 0) {
          const utterance = isFinalsRef.current.join(' ');
          setTranscript(prev => prev ? `${prev} ${utterance}` : utterance);
          isFinalsRef.current = [];
        }
      });

      // Handle errors
      connection.on(LiveTranscriptionEvents.Error, (err) => {
        console.error('Deepgram error:', err);
        setError('Transcription error occurred');
        stopRecording();
      });

      // Handle connection close
      connection.on(LiveTranscriptionEvents.Close, () => {
        console.log('Deepgram connection closed');
      });

    } catch (err) {
      console.error('Error starting recording:', err);
      setError(err instanceof Error ? err.message : 'Failed to start recording');
      setIsRecording(false);
    }
  };

  const stopRecording = () => {
    // Stop MediaRecorder
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current = null;
    }

    // Stop all tracks
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    // Close WebSocket connection
    if (connectionRef.current) {
      connectionRef.current.requestClose();
      connectionRef.current = null;
    }

    setIsRecording(false);
  };

  if (!isSupported) {
    return (
      <div className="text-red-500 text-sm">
        Browser does not support audio recording
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <button
        onPointerDown={startRecording}
        onPointerUp={stopRecording}
        onPointerLeave={stopRecording} // Safety: stop if pointer leaves button
        disabled={!isSupported}
        className={`
          px-6 py-3 rounded-lg font-medium transition-all
          ${isRecording 
            ? 'bg-red-600 hover:bg-red-700 text-white scale-95' 
            : 'bg-zinc-800 hover:bg-zinc-700 text-white'
          }
          disabled:opacity-50 disabled:cursor-not-allowed
          select-none
        `}
      >
        {isRecording ? '🎤 Recording... (release to stop)' : '🎙️ Push to Talk'}
      </button>

      {error && (
        <div className="text-red-500 text-sm">
          Error: {error}
        </div>
      )}

      {transcript && (
        <div className="p-4 bg-zinc-900 rounded-lg">
          <p className="text-sm text-zinc-300">Transcript:</p>
          <p className="text-white mt-1">{transcript}</p>
        </div>
      )}

      <div className="text-xs text-zinc-600">
        ⚠️ WARNING: This PoC exposes the API key in the browser. NOT FOR PRODUCTION USE!
      </div>
    </div>
  );
}