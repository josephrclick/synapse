'use client';

import ChatWindow from './components/chat/ChatWindow';
import VoicePanel from './components/voice/VoicePanel';

export default function Home() {
  return (
    <div className="flex h-full px-[10%] pb-[5%]">
      {/* Two column layout - responsive */}
      <div className="flex w-full h-full flex-col lg:flex-row rounded-lg overflow-hidden border border-gray-800">
        {/* Left column - Voice transcription */}
        <div className="w-full lg:w-1/2 h-1/2 lg:h-full border-b lg:border-b-0 lg:border-r border-gray-800">
          <VoicePanel />
        </div>
        
        {/* Right column - Text chat */}
        <div className="w-full lg:w-1/2 h-1/2 lg:h-full">
          <ChatWindow />
        </div>
      </div>
    </div>
  );
}