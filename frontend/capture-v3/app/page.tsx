'use client';

import { useState, useEffect } from 'react';
import ChatWindow from './components/chat/ChatWindow';
import SplashScreen from './components/SplashScreen';
import DeepgramPocButton from './components/voice/DeepgramPocButton';

export default function Home() {
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    const hasSeenSplash = sessionStorage.getItem('hasSeenSplash');
    if (hasSeenSplash) {
      setShowSplash(false);
    }
  }, []);

  const handleSplashComplete = () => {
    sessionStorage.setItem('hasSeenSplash', 'true');
    setShowSplash(false);
  };

  if (showSplash) {
    return <SplashScreen onComplete={handleSplashComplete} />;
  }

  return (
    <div className="flex flex-col h-full">
      <ChatWindow />
      
      {/* Voice Transcription PoC - Interview Prep */}
      <div className="max-w-4xl mx-auto p-4 mt-4">
        <DeepgramPocButton />
      </div>
    </div>
  );
}