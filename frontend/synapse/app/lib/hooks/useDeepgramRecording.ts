'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { createClient, LiveTranscriptionEvents, LiveClient } from '@deepgram/sdk';

export interface UseDeepgramRecordingReturn {
  isRecording: boolean;
  isProcessing: boolean;
  transcript: string;
  error: string | null;
  isSupported: boolean;
  startRecording: () => Promise<void>;
  stopRecording: () => void;
  clearTranscript: () => void;
}

/**
 * Custom hook for Deepgram voice recording and transcription
 * 
 * WARNING: This uses an API key exposed in the browser - DO NOT USE IN PRODUCTION!
 * For production, implement a server-side WebSocket proxy.
 */
export function useDeepgramRecording(): UseDeepgramRecordingReturn {
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
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

  const startRecording = useCallback(async () => {
    try {
      setError(null);
      setTranscript('');
      setIsProcessing(true);
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
        setIsProcessing(false);
        
        // Create MediaRecorder with browser-compatible settings
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
        
        // Provide more specific error messages
        if (err.message?.includes('UNAUTHORIZED') || err.message?.includes('Authentication failed')) {
          setError('Invalid Deepgram API key. Please check your configuration.');
        } else if (err.message?.includes('WebSocket connection error')) {
          setError('Failed to connect to Deepgram. Please check your API key and internet connection.');
        } else {
          setError('Transcription error occurred: ' + (err.message || 'Unknown error'));
        }
        
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
      setIsProcessing(false);
    }
  }, []);

  const stopRecording = useCallback(() => {
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
    setIsProcessing(false);
  }, []);

  const clearTranscript = useCallback(() => {
    setTranscript('');
    setError(null);
  }, []);

  return {
    isRecording,
    isProcessing,
    transcript,
    error,
    isSupported,
    startRecording,
    stopRecording,
    clearTranscript,
  };
}