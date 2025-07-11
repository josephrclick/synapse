'use client';

import { useState, useRef, useEffect } from 'react';
import { createClient, LiveTranscriptionEvents, LiveClient } from '@deepgram/sdk';

/**
 * EnhancedDeepgramButton - Voice transcription with auto-clipboard functionality
 * 
 * Features:
 * - Push-to-talk or toggle recording modes
 * - Auto-copies transcript to clipboard
 * - Visual feedback for clipboard operations
 * - Persistent transcript display
 * 
 * WARNING: This is a proof-of-concept for learning purposes only!
 * The API key is exposed in the browser - DO NOT USE IN PRODUCTION!
 */

interface ClipboardStatus {
  state: 'idle' | 'copying' | 'copied' | 'error';
  message?: string;
}

export default function EnhancedDeepgramButton() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSupported, setIsSupported] = useState(true);
  const [clipboardStatus, setClipboardStatus] = useState<ClipboardStatus>({ state: 'idle' });
  const [recordingMode, setRecordingMode] = useState<'push' | 'toggle'>('toggle');

  // Refs to hold our instances
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const connectionRef = useRef<LiveClient | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const isFinalsRef = useRef<string[]>([]);
  const clipboardTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Check browser support on mount
  useEffect(() => {
    const checkSupport = 
      typeof window !== 'undefined' &&
      navigator.mediaDevices?.getUserMedia &&
      window.MediaRecorder &&
      navigator.clipboard;
    
    setIsSupported(!!checkSupport);
    
    if (!checkSupport) {
      setError('Your browser does not support audio recording or clipboard access');
    }
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
      }
      
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
      
      if (connectionRef.current) {
        connectionRef.current.requestClose();
      }

      if (clipboardTimeoutRef.current) {
        clearTimeout(clipboardTimeoutRef.current);
      }
    };
  }, []);

  // Auto-copy to clipboard when transcript changes
  useEffect(() => {
    if (transcript && transcript.trim().length > 0) {
      copyToClipboard(transcript);
    }
  }, [transcript]);

  const copyToClipboard = async (text: string) => {
    try {
      setClipboardStatus({ state: 'copying' });
      await navigator.clipboard.writeText(text);
      setClipboardStatus({ state: 'copied', message: 'Transcript copied to clipboard!' });
      
      // Reset status after 3 seconds
      if (clipboardTimeoutRef.current) {
        clearTimeout(clipboardTimeoutRef.current);
      }
      clipboardTimeoutRef.current = setTimeout(() => {
        setClipboardStatus({ state: 'idle' });
      }, 3000);
    } catch (err) {
      console.error('Failed to copy to clipboard:', err);
      setClipboardStatus({ 
        state: 'error', 
        message: 'Failed to copy. Click transcript to select manually.' 
      });
      
      // Reset error status after 5 seconds
      if (clipboardTimeoutRef.current) {
        clearTimeout(clipboardTimeoutRef.current);
      }
      clipboardTimeoutRef.current = setTimeout(() => {
        setClipboardStatus({ state: 'idle' });
      }, 5000);
    }
  };

  const clearTranscript = () => {
    setTranscript('');
    setClipboardStatus({ state: 'idle' });
  };

  const startRecording = async () => {
    try {
      setError(null);
      setTranscript('');
      isFinalsRef.current = [];
      setClipboardStatus({ state: 'idle' });

      // Get microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      // Initialize Deepgram client
      const apiKey = process.env.NEXT_PUBLIC_DEEPGRAM_API_KEY;
      if (!apiKey) {
        throw new Error('Deepgram API key not found in environment variables');
      }

      const deepgram = createClient(apiKey);
      
      // Create live transcription connection
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
        
        // Create MediaRecorder
        const mimeTypes = [
          'audio/webm;codecs=opus',
          'audio/webm',
          'audio/ogg;codecs=opus',
          'audio/mp4',
        ];
        
        let mediaRecorder: MediaRecorder | null = null;
        let selectedMimeType = '';
        
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
            mediaRecorder = new MediaRecorder(stream);
          }
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

        // Start recording
        mediaRecorder.start(250);
        setIsRecording(true);
      });

      // Handle transcription results
      connection.on(LiveTranscriptionEvents.Transcript, (data) => {
        const sentence = data.channel.alternatives[0].transcript;
        
        if (sentence.length === 0) {
          return;
        }

        if (data.is_final) {
          isFinalsRef.current.push(sentence);
          
          if (data.speech_final) {
            const utterance = isFinalsRef.current.join(' ');
            setTranscript(prev => prev ? `${prev} ${utterance}` : utterance);
            isFinalsRef.current = [];
          }
        }
      });

      // Handle utterance end
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
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current = null;
    }

    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    if (connectionRef.current) {
      connectionRef.current.requestClose();
      connectionRef.current = null;
    }

    setIsRecording(false);
  };

  const toggleRecording = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  if (!isSupported) {
    return (
      <div className="text-red-500 text-sm">
        Browser does not support required features
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Mode selector */}
      <div className="flex gap-2 justify-center">
        <button
          onClick={() => setRecordingMode('push')}
          className={`px-3 py-1 rounded text-sm ${
            recordingMode === 'push' 
              ? 'bg-cyan-600 text-white' 
              : 'bg-zinc-800 text-zinc-400'
          }`}
        >
          Push to Talk
        </button>
        <button
          onClick={() => setRecordingMode('toggle')}
          className={`px-3 py-1 rounded text-sm ${
            recordingMode === 'toggle' 
              ? 'bg-cyan-600 text-white' 
              : 'bg-zinc-800 text-zinc-400'
          }`}
        >
          Toggle Mode
        </button>
      </div>

      {/* Recording button */}
      {recordingMode === 'push' ? (
        <button
          onPointerDown={startRecording}
          onPointerUp={stopRecording}
          onPointerLeave={stopRecording}
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
      ) : (
        <button
          onClick={toggleRecording}
          disabled={!isSupported}
          className={`
            px-6 py-3 rounded-lg font-medium transition-all
            ${isRecording 
              ? 'bg-red-600 hover:bg-red-700 text-white animate-pulse' 
              : 'bg-zinc-800 hover:bg-zinc-700 text-white'
            }
            disabled:opacity-50 disabled:cursor-not-allowed
          `}
        >
          {isRecording ? '⏹️ Stop Recording' : '🎙️ Start Recording'}
        </button>
      )}

      {/* Clipboard status */}
      {clipboardStatus.state !== 'idle' && (
        <div className={`text-sm text-center ${
          clipboardStatus.state === 'copied' ? 'text-green-500' :
          clipboardStatus.state === 'copying' ? 'text-yellow-500' :
          'text-red-500'
        }`}>
          {clipboardStatus.state === 'copying' && '📋 Copying to clipboard...'}
          {clipboardStatus.state === 'copied' && '✅ ' + clipboardStatus.message}
          {clipboardStatus.state === 'error' && '❌ ' + clipboardStatus.message}
        </div>
      )}

      {/* Error display */}
      {error && (
        <div className="text-red-500 text-sm">
          Error: {error}
        </div>
      )}

      {/* Transcript display */}
      {transcript && (
        <div className="relative group">
          <div 
            className="p-4 bg-zinc-900 rounded-lg cursor-text select-all"
            onClick={() => {
              // Select all text on click for easy manual copying
              const selection = window.getSelection();
              const range = document.createRange();
              range.selectNodeContents(event.currentTarget);
              selection?.removeAllRanges();
              selection?.addRange(range);
            }}
          >
            <div className="flex justify-between items-start mb-2">
              <p className="text-sm text-zinc-300">Transcript:</p>
              <div className="flex gap-2">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    copyToClipboard(transcript);
                  }}
                  className="text-xs px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded"
                >
                  📋 Copy
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    clearTranscript();
                  }}
                  className="text-xs px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded"
                >
                  🗑️ Clear
                </button>
              </div>
            </div>
            <p className="text-white mt-1 whitespace-pre-wrap">{transcript}</p>
          </div>
          
          {/* Hover hint */}
          <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 bg-zinc-800 text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
            Click to select all
          </div>
        </div>
      )}

      {/* Instructions */}
      <div className="text-xs text-zinc-500 space-y-1">
        <p>📋 Transcript auto-copies to clipboard when you stop recording</p>
        <p>🖱️ Click transcript to select all text manually</p>
        <p>⌨️ Switch to any app and paste (Cmd/Ctrl+V)</p>
      </div>

      <div className="text-xs text-zinc-600">
        ⚠️ WARNING: This PoC exposes the API key in the browser. NOT FOR PRODUCTION USE!
      </div>
    </div>
  );
}