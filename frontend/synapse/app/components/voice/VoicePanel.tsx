'use client';

import EnhancedDeepgramButton from './EnhancedDeepgramButton';

export default function VoicePanel() {
  return (
    <div className="flex flex-col h-full p-4">
      {/* Header matching the chat panel style */}
      <header className="mb-4 text-center flex-shrink-0">
        <div className="flex items-center justify-center space-x-2 mb-2">
          <div className="w-2 h-2 bg-purple-400 rounded-full animate-pulse"></div>
          <h1 className="text-3xl font-bold text-gray-100">Voice Transcription</h1>
          <div className="w-2 h-2 bg-purple-400 rounded-full animate-pulse" style={{ animationDelay: '0.5s' }}></div>
        </div>
        <p className="text-gray-400">Speak and transcribe in real-time</p>
      </header>
      
      {/* Voice controls and transcript display */}
      <div className="flex-1 flex flex-col bg-gray-900 rounded-lg overflow-hidden min-h-0">
        <EnhancedDeepgramButton />
      </div>
    </div>
  );
}