'use client';

import { useReducer, useCallback, useEffect } from 'react';
import { voiceReducer, initialVoiceState } from '@/app/lib/voice-reducer';
import { useDeepgramRecording } from '@/app/lib/hooks/useDeepgramRecording';
import TranscriptList from './TranscriptList';
import VoiceToggle from './VoiceToggle';

export default function VoiceWindow() {
  const [state, dispatch] = useReducer(voiceReducer, initialVoiceState);
  const {
    isRecording,
    isProcessing,
    transcript,
    error: recordingError,
    isSupported,
    startRecording,
    stopRecording,
    clearTranscript,
  } = useDeepgramRecording();

  // Update state when recording status changes
  useEffect(() => {
    dispatch({ type: 'SET_RECORDING', payload: isRecording });
  }, [isRecording]);

  // Update state when processing status changes
  useEffect(() => {
    dispatch({ type: 'SET_PROCESSING', payload: isProcessing });
  }, [isProcessing]);

  // Update state when recording error occurs
  useEffect(() => {
    if (recordingError) {
      dispatch({ type: 'SET_ERROR', payload: recordingError });
    }
  }, [recordingError]);

  // Add transcript when recording stops and there's content
  useEffect(() => {
    if (!isRecording && transcript && transcript.trim()) {
      dispatch({ type: 'ADD_TRANSCRIPT', payload: { content: transcript } });
      clearTranscript();
    }
  }, [isRecording, transcript, clearTranscript]);

  const handleToggle = useCallback(async () => {
    if (isRecording) {
      stopRecording();
    } else {
      await startRecording();
    }
  }, [isRecording, startRecording, stopRecording]);

  return (
    <div className="flex flex-col h-full max-w-4xl mx-auto p-4">
      <header className="mb-4 text-center flex-shrink-0">
        <div className="flex items-center justify-center space-x-2 mb-2">
          <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse"></div>
          <h1 className="text-3xl font-bold text-gray-100">Neural Chat</h1>
          <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse" style={{ animationDelay: '0.5s' }}></div>
        </div>
        <p className="text-gray-400">Voice transcription interface</p>
      </header>
      
      <div className="flex-1 flex flex-col bg-gray-900 rounded-lg overflow-hidden min-h-0">
        <TranscriptList 
          transcripts={state.transcripts} 
          isProcessing={state.isProcessing}
          error={state.error || (!isSupported ? 'Browser does not support audio recording' : null)}
        />
        
        <VoiceToggle
          isRecording={state.isRecording}
          isProcessing={state.isProcessing}
          onToggle={handleToggle}
          disabled={!isSupported}
        />
      </div>
    </div>
  );
}