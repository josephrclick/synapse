'use client';

import { useEffect, useRef } from 'react';

interface SplashScreenProps {
  onComplete: () => void;
}

export default function SplashScreen({ onComplete }: SplashScreenProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const isMountedRef = useRef(true);

  useEffect(() => {
    isMountedRef.current = true;
    
    const timer = setTimeout(() => {
      if (isMountedRef.current) {
        onComplete();
      }
    }, 5200);

    const video = videoRef.current;
    if (video) {
      video.play().catch(error => {
        console.error('Error playing video:', error);
        if (isMountedRef.current) {
          onComplete();
        }
      });
    }

    return () => {
      isMountedRef.current = false;
      clearTimeout(timer);
      
      // Clean up video to prevent interruption error
      if (video) {
        video.pause();
        video.removeAttribute('src');
        video.load();
      }
    };
  }, [onComplete]);

  return (
    <div className="fixed inset-0 z-50 bg-black flex items-center justify-center">
      <video
        ref={videoRef}
        className="w-1/2 h-1/2 object-contain"
        src="/synapse-splash.mp4"
        muted
        playsInline
        preload="auto"
      />
    </div>
  );
}