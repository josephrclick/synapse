'use client';

import ChatWindow from './components/chat/ChatWindow';
import EnhancedDeepgramButton from './components/voice/EnhancedDeepgramButton';

export default function Home() {
  return (
    <div className="flex flex-col h-full">
      <ChatWindow />
      
      {/* Enhanced Voice Transcription with Auto-Clipboard */}
      <div className="max-w-4xl mx-auto p-4 mt-4">
        <EnhancedDeepgramButton />
      </div>
    </div>
  );
}