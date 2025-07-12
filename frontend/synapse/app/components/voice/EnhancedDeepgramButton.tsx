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

type ConnectionStatus = 'idle' | 'connecting' | 'connected' | 'error';

export default function EnhancedDeepgramButton() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [interimTranscript, setInterimTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSupported, setIsSupported] = useState(true);
  const [clipboardStatus, setClipboardStatus] = useState<ClipboardStatus>({ state: 'idle' });
  const [recordingMode, setRecordingMode] = useState<'push' | 'toggle'>('toggle');
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('idle');
  const [previousTranscript, setPreviousTranscript] = useState('');
  const [recordingStartTime, setRecordingStartTime] = useState<number | null>(null);
  const [wordCount, setWordCount] = useState(0);
  const [enableTimestamps, setEnableTimestamps] = useState(false);
  const [transcriptWithTimestamps, setTranscriptWithTimestamps] = useState<Array<{text: string, timestamp: string}>>([]);
  const [audioChunkCount, setAudioChunkCount] = useState(0);
  const [audioLevel, setAudioLevel] = useState(0);

  // Refs to hold our instances
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const connectionRef = useRef<LiveClient | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const isFinalsRef = useRef<string[]>([]);
  const clipboardTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const shouldBeRecordingRef = useRef<boolean>(false);
  const retryTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const transcriptEndRef = useRef<HTMLDivElement | null>(null);

  // Check browser support on mount
  useEffect(() => {
    const checkSupport = 
      typeof window !== 'undefined' &&
      !!navigator.mediaDevices?.getUserMedia &&
      !!window.MediaRecorder &&
      !!navigator.clipboard;
    
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

      // Copy ref value to avoid React warning
      const retryTimeout = retryTimeoutRef.current;
      if (retryTimeout) {
        clearTimeout(retryTimeout);
      }
    };
  }, []);

  // Auto-copy to clipboard when transcript changes
  useEffect(() => {
    if (transcript && transcript.trim().length > 0) {
      copyToClipboard(transcript);
    }
  }, [transcript]);

  // Update word count when transcript changes
  useEffect(() => {
    const words = transcript.trim().split(/\s+/).filter(word => word.length > 0);
    setWordCount(words.length);
  }, [transcript]);

  // Autosave to localStorage
  useEffect(() => {
    const saveData = {
      transcript,
      transcriptWithTimestamps,
      enableTimestamps,
      recordingMode,
      savedAt: new Date().toISOString()
    };
    
    try {
      localStorage.setItem('deepgram-transcript-autosave', JSON.stringify(saveData));
    } catch (e) {
      console.error('Failed to autosave transcript:', e);
    }
  }, [transcript, transcriptWithTimestamps, enableTimestamps, recordingMode]);

  // Load saved data on mount
  useEffect(() => {
    try {
      const savedData = localStorage.getItem('deepgram-transcript-autosave');
      if (savedData) {
        const parsed = JSON.parse(savedData);
        
        // Only restore if saved within last 24 hours
        const savedTime = new Date(parsed.savedAt).getTime();
        const dayAgo = Date.now() - (24 * 60 * 60 * 1000);
        
        if (savedTime > dayAgo && parsed.transcript) {
          // Show confirmation before restoring
          const shouldRestore = window.confirm(
            `Found an autosaved transcript from ${new Date(parsed.savedAt).toLocaleString()}. Would you like to restore it?`
          );
          
          if (shouldRestore) {
            setTranscript(parsed.transcript || '');
            setTranscriptWithTimestamps(parsed.transcriptWithTimestamps || []);
            setEnableTimestamps(parsed.enableTimestamps || false);
            setRecordingMode(parsed.recordingMode || 'toggle');
          } else {
            // Clear autosave if user declines
            localStorage.removeItem('deepgram-transcript-autosave');
          }
        }
      }
    } catch (e) {
      console.error('Failed to load autosaved transcript:', e);
    }
  }, []); // Only run on mount

  // Auto-scroll to bottom when transcript updates
  useEffect(() => {
    if (transcriptEndRef.current) {
      transcriptEndRef.current.scrollIntoView({ behavior: 'smooth', block: 'end' });
    }
  }, [transcript, interimTranscript]);

  // Update recording duration every second
  useEffect(() => {
    if (isRecording && recordingStartTime) {
      const interval = setInterval(() => {
        // Force re-render to update duration display
        setRecordingStartTime(prev => prev);
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [isRecording, recordingStartTime]);

  // Auto-clear errors after 5 seconds
  useEffect(() => {
    if (error) {
      const timeout = setTimeout(() => {
        setError(null);
      }, 5000);
      return () => clearTimeout(timeout);
    }
  }, [error]);

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
    if (transcript) {
      setPreviousTranscript(transcript);
    }
    setTranscript('');
    setInterimTranscript('');
    setTranscriptWithTimestamps([]);
    setClipboardStatus({ state: 'idle' });
    
    // Clear autosave when user explicitly clears
    try {
      localStorage.removeItem('deepgram-transcript-autosave');
    } catch (e) {
      console.error('Failed to clear autosave:', e);
    }
  };

  const undoClear = () => {
    if (previousTranscript) {
      setTranscript(previousTranscript);
      setPreviousTranscript('');
    }
  };

  const exportTranscript = () => {
    const content = enableTimestamps && transcriptWithTimestamps.length > 0
      ? transcriptWithTimestamps.map(item => `[${item.timestamp}] ${item.text}`).join('\n')
      : transcript;
    
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `transcript-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const formatDuration = (ms: number) => {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}:${(minutes % 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
    }
    return `${minutes}:${(seconds % 60).toString().padStart(2, '0')}`;
  };

  const formatTimestamp = (ms: number) => {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  const startRecording = async () => {
    try {
      console.log(`[startRecording] Starting recording process in ${recordingMode} mode`);
      setError(null);
      setTranscript('');
      setInterimTranscript('');
      setTranscriptWithTimestamps([]);
      isFinalsRef.current = [];
      setClipboardStatus({ state: 'idle' });
      shouldBeRecordingRef.current = true;
      setConnectionStatus('connecting');
      setRecordingStartTime(Date.now());
      setAudioChunkCount(0);

      // Get microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 16000
        }
      });
      streamRef.current = stream;
      const audioTracks = stream.getAudioTracks();
      console.log('[startRecording] Got audio stream with tracks:', audioTracks.length);
      audioTracks.forEach((track, i) => {
        console.log(`[startRecording] Track ${i}:`, {
          enabled: track.enabled,
          muted: track.muted,
          readyState: track.readyState,
          label: track.label,
          settings: track.getSettings()
        });
      });

      // Set up audio level monitoring
      const audioContext = new AudioContext();
      const analyser = audioContext.createAnalyser();
      const microphone = audioContext.createMediaStreamSource(stream);
      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      
      microphone.connect(analyser);
      
      const checkAudioLevel = () => {
        analyser.getByteFrequencyData(dataArray);
        const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
        setAudioLevel(Math.round(average));
        
        if (shouldBeRecordingRef.current) {
          requestAnimationFrame(checkAudioLevel);
        }
      };
      
      checkAudioLevel();

      // Create MediaRecorder first, before Deepgram connection
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
      console.log('[startRecording] Deepgram connection created');

      // Buffer to store audio chunks while waiting for connection
      const audioBuffer: Blob[] = [];

      // Set up audio data handler immediately
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          console.log(`[ondataavailable] Audio chunk received: ${event.data.size} bytes, type: ${event.data.type}`);
          setAudioChunkCount(prev => prev + 1);
          
          // Check if we're still supposed to be recording (important for push-to-talk)
          if (!shouldBeRecordingRef.current) {
            console.log('[ondataavailable] Recording stopped, discarding chunk');
            return;
          }
          
          if (connectionRef.current && connectionRef.current.getReadyState() === 1) {
            // Connection is open, send data directly
            console.log('[ondataavailable] Sending directly to Deepgram');
            try {
              connectionRef.current.send(event.data);
              console.log('[ondataavailable] Successfully sent audio chunk to Deepgram');
            } catch (err) {
              console.error('[ondataavailable] Error sending audio to Deepgram:', err);
            }
          } else {
            // Connection not ready, buffer the data
            console.log('[ondataavailable] Buffering audio chunk, connection state:', connectionRef.current?.getReadyState());
            audioBuffer.push(event.data);
          }
        } else {
          console.log('[ondataavailable] Empty audio chunk received');
        }
      };

      // Add onstop handler to ensure we get final data
      mediaRecorder.onstop = () => {
        console.log('[MediaRecorder] Recording stopped');
      };

      // Start recording immediately with smaller timeslice for push-to-talk
      const timeslice = recordingMode === 'push' ? 100 : 250;
      mediaRecorder.start(timeslice);
      console.log(`[startRecording] MediaRecorder started with timeslice: ${timeslice}ms`);
      setIsRecording(true);

      // Set up connection event handlers
      connection.on(LiveTranscriptionEvents.Open, () => {
        console.log('[Deepgram Open] Connection opened, readyState:', connection.getReadyState());
        setConnectionStatus('connected');
        
        // Send any buffered audio chunks
        if (audioBuffer.length > 0) {
          // Check if we should still be recording (important for push-to-talk)
          if (shouldBeRecordingRef.current) {
            console.log(`[Deepgram Open] Sending ${audioBuffer.length} buffered audio chunks`);
            let sentCount = 0;
            audioBuffer.forEach((chunk, index) => {
              if (connectionRef.current && connectionRef.current.getReadyState() === 1) {
                try {
                  connectionRef.current.send(chunk);
                  sentCount++;
                  console.log(`[Deepgram Open] Sent buffered chunk ${index + 1}/${audioBuffer.length}, size: ${chunk.size}`);
                } catch (err) {
                  console.error(`[Deepgram Open] Error sending buffered chunk ${index + 1}:`, err);
                }
              }
            });
            console.log(`[Deepgram Open] Successfully sent ${sentCount}/${audioBuffer.length} buffered chunks`);
          } else {
            console.log('[Deepgram Open] Recording stopped before connection opened, discarding buffer');
          }
          audioBuffer.length = 0; // Clear the buffer
        } else {
          console.log('[Deepgram Open] No buffered audio to send');
        }
      });

      // Handle transcription results
      connection.on(LiveTranscriptionEvents.Transcript, (data) => {
        console.log('[Transcript event] Received transcript data:', data);
        
        // Handle the 'Results' type format
        if (data.type === 'Results' && data.channel) {
          const sentence = data.channel.alternatives[0].transcript;
          
          // Ignore empty transcripts
          if (sentence.length === 0) {
            return;
          }

          if (data.is_final) {
            // Collect final transcripts
            isFinalsRef.current.push(sentence);
            setInterimTranscript(''); // Clear interim when we get finals
            
            // Speech final means end of utterance detected
            if (data.speech_final) {
              const utterance = isFinalsRef.current.join(' ');
              console.log('[Transcript] Final utterance:', utterance);
              setTranscript(prev => prev ? `${prev} ${utterance}` : utterance);
              
              // Add timestamp if enabled
              if (enableTimestamps && recordingStartTime) {
                const timestamp = formatTimestamp(Date.now() - recordingStartTime);
                setTranscriptWithTimestamps(prev => [...prev, { text: utterance, timestamp }]);
              }
              
              isFinalsRef.current = [];
            }
          } else {
            // Show interim results in real-time
            console.log('[Transcript] Interim:', sentence);
            setInterimTranscript(sentence);
          }
        }
      });

      // Handle utterance end (backup for speech_final)
      connection.on(LiveTranscriptionEvents.UtteranceEnd, () => {
        if (isFinalsRef.current.length > 0) {
          const utterance = isFinalsRef.current.join(' ');
          setTranscript(prev => prev ? `${prev} ${utterance}` : utterance);
          
          // Add timestamp if enabled
          if (enableTimestamps && recordingStartTime) {
            const timestamp = formatTimestamp(Date.now() - recordingStartTime);
            setTranscriptWithTimestamps(prev => [...prev, { text: utterance, timestamp }]);
          }
          
          isFinalsRef.current = [];
        }
        setInterimTranscript(''); // Clear any remaining interim
      });

      // Handle errors
      connection.on(LiveTranscriptionEvents.Error, (err) => {
        console.error('Deepgram error:', err);
        setError('Transcription error occurred: ' + (err.message || 'Unknown error'));
        setConnectionStatus('error');
        stopRecording();
      });

      connection.on(LiveTranscriptionEvents.Close, () => {
        console.log('Deepgram connection closed');
        setConnectionStatus('idle');
      });

    } catch (err) {
      console.error('Error starting recording:', err);
      setError(err instanceof Error ? err.message : 'Failed to start recording');
      setIsRecording(false);
      setConnectionStatus('error');
      // Clean up on error
      stopRecording();
    }
  };

  const stopRecording = () => {
    console.log('[stopRecording] Stopping recording, shouldBeRecordingRef:', shouldBeRecordingRef.current);
    shouldBeRecordingRef.current = false;
    
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      console.log('[stopRecording] MediaRecorder state:', mediaRecorderRef.current.state);
      console.log('[stopRecording] Stopping MediaRecorder');
      // Force a final data event before stopping
      if (mediaRecorderRef.current.state === 'recording') {
        mediaRecorderRef.current.requestData();
      }
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current = null;
    }

    if (streamRef.current) {
      console.log('[stopRecording] Stopping audio stream');
      streamRef.current.getTracks().forEach(track => {
        console.log('[stopRecording] Stopping track:', track.kind, track.label);
        track.stop();
      });
      streamRef.current = null;
    }

    if (connectionRef.current) {
      console.log('[stopRecording] Closing Deepgram connection');
      connectionRef.current.requestClose();
      connectionRef.current = null;
    }

    setIsRecording(false);
    setConnectionStatus('idle');
    setInterimTranscript(''); // Clear any remaining interim
    setAudioLevel(0); // Clear audio level
    console.log('[stopRecording] Recording stopped completely');
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
    <div className="flex flex-col h-full gap-4">
      {/* Transcript display area - takes most of the space */}
      <div className="flex-1 flex flex-col min-h-0">
        {(transcript || interimTranscript) ? (
          <div className="relative group flex-1 flex flex-col">
            <div 
              className="flex-1 p-4 bg-zinc-900 rounded-lg cursor-text select-all overflow-y-auto"
              onClick={(e) => {
                // Only select all if clicking on the text area, not buttons
                const target = e.target as HTMLElement;
                if (target === e.currentTarget || target.tagName === 'P' || target.tagName === 'SPAN' || target.tagName === 'DIV') {
                  const selection = window.getSelection();
                  const range = document.createRange();
                  range.selectNodeContents(e.currentTarget);
                  selection?.removeAllRanges();
                  selection?.addRange(range);
                }
              }}
            >
              <div className="flex justify-between items-start mb-2">
                <p className="text-sm text-zinc-300">Transcript:</p>
                <div className="flex gap-2">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      exportTranscript();
                    }}
                    className="text-xs px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded"
                  >
                    💾 Export
                  </button>
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
                  {previousTranscript && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        undoClear();
                      }}
                      className="text-xs px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded"
                    >
                      ↩️ Undo
                    </button>
                  )}
                </div>
              </div>
              <div className="text-white mt-1 whitespace-pre-wrap">
                {enableTimestamps && transcriptWithTimestamps.length > 0 ? (
                  transcriptWithTimestamps.map((item, index) => (
                    <div key={index} className="mb-1">
                      <span className="text-zinc-500 text-xs">[{item.timestamp}]</span> {item.text}
                    </div>
                  ))
                ) : (
                  <span>{transcript}</span>
                )}
                {interimTranscript && (
                  <span className="text-zinc-400 italic"> {interimTranscript}</span>
                )}
                <div ref={transcriptEndRef} />
              </div>
            </div>
            
            {/* Hover hint */}
            <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 bg-zinc-800 text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
              Click to select all
            </div>
          </div>
        ) : (
          <div className="flex-1 flex items-center justify-center text-zinc-500 text-sm">
            <p>Start recording to see transcript here</p>
          </div>
        )}
      </div>

      {/* Controls section - fixed at bottom */}
      <div className="flex-shrink-0 space-y-3">
        {/* Session stats */}
        {(isRecording || transcript) && (
          <div className="flex justify-between text-xs text-zinc-500">
            <div className="flex gap-4">
              {isRecording && recordingStartTime && (
                <span>🕐 {formatDuration(Date.now() - recordingStartTime)}</span>
              )}
              {wordCount > 0 && <span>📝 {wordCount} words</span>}
              {isRecording && <span>🎵 {audioChunkCount} chunks</span>}
              {isRecording && audioLevel > 0 && (
                <span className="text-cyan-400">
                  🎙️ {Array(Math.min(5, Math.floor(audioLevel / 25))).fill('▪').join('')}
                </span>
              )}
              {transcript && <span className="text-green-600">💾 Autosaved</span>}
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setEnableTimestamps(!enableTimestamps)}
                className={`px-2 py-1 rounded ${
                  enableTimestamps ? 'bg-cyan-600 text-white' : 'bg-zinc-800 text-zinc-400'
                }`}
              >
                {enableTimestamps ? '🕐 Timestamps ON' : '🕐 Timestamps OFF'}
              </button>
            </div>
          </div>
        )}

        {/* Mode selector */}
        <div className="flex gap-2 justify-center">
          <button
            onClick={() => !isRecording && setRecordingMode('push')}
            disabled={isRecording}
            className={`px-3 py-1 rounded text-sm transition-all flex-1 ${
              recordingMode === 'push' 
                ? 'bg-purple-600 text-white' 
                : 'bg-zinc-800 text-zinc-400'
            } ${isRecording ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
          >
            Push to Talk
          </button>
          <button
            onClick={() => !isRecording && setRecordingMode('toggle')}
            disabled={isRecording}
            className={`px-3 py-1 rounded text-sm transition-all flex-1 ${
              recordingMode === 'toggle' 
                ? 'bg-purple-600 text-white' 
                : 'bg-zinc-800 text-zinc-400'
            } ${isRecording ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
          >
            Toggle Mode
          </button>
        </div>

        {/* Connection status indicator */}
        {connectionStatus !== 'idle' && (
          <div className={`text-xs text-center ${
            connectionStatus === 'connecting' ? 'text-yellow-500' :
            connectionStatus === 'connected' ? 'text-green-500' :
            'text-red-500'
          }`}>
            {connectionStatus === 'connecting' && '🔄 Connecting to Deepgram...'}
            {connectionStatus === 'connected' && '✅ Connected'}
            {connectionStatus === 'error' && '❌ Connection error'}
          </div>
        )}

        {/* Recording button */}
        {recordingMode === 'push' ? (
          <button
            onPointerDown={startRecording}
            onPointerUp={stopRecording}
            onPointerLeave={stopRecording}
            disabled={!isSupported}
            className={`
              w-full px-6 py-3 rounded-lg font-medium transition-all
              ${isRecording 
                ? 'bg-red-600 hover:bg-red-700 text-white scale-95' 
                : 'bg-zinc-800 hover:bg-zinc-700 text-white'
              }
              disabled:opacity-50 disabled:cursor-not-allowed
              select-none
            `}
          >
            {isRecording ? (
              connectionStatus === 'connecting' ? '🔄 Connecting... (release to stop)' : 
              '🎤 Recording... (release to stop)'
            ) : '🎙️ Push to Talk'}
          </button>
        ) : (
          <button
            onClick={toggleRecording}
            disabled={!isSupported}
            className={`
              w-full px-6 py-3 rounded-lg font-medium transition-all
              ${isRecording 
                ? 'bg-red-600 hover:bg-red-700 text-white animate-pulse' 
                : 'bg-zinc-800 hover:bg-zinc-700 text-white'
              }
              disabled:opacity-50 disabled:cursor-not-allowed
            `}
          >
            {isRecording ? (
              connectionStatus === 'connecting' ? '🔄 Connecting...' : 
              '⏹️ Stop Recording'
            ) : '🎙️ Start Recording'}
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
          <div className="text-red-500 text-sm flex items-center justify-between">
            <span>Error: {error}</span>
            <button
              onClick={() => setError(null)}
              className="ml-2 text-xs px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded"
            >
              ✕
            </button>
          </div>
        )}

        {/* Instructions */}
        <div className="text-xs text-zinc-500 space-y-1">
          <p>💾 Autosaves transcript | 📋 Auto-copies when recording stops</p>
          <p>✨ <span className="italic">Interim text</span> shows live transcription</p>
        </div>
      </div>
    </div>
  );
}