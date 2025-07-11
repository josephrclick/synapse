'use client';

import MessageList from '@/app/components/chat/MessageList';
import { Message } from '@/app/types/chat';

interface TranscriptListProps {
  transcripts: Message[];
  isProcessing: boolean;
  error: string | null;
}

export default function TranscriptList({ transcripts, isProcessing, error }: TranscriptListProps) {
  // If no transcripts and not processing, show voice-specific empty state
  if (transcripts.length === 0 && !isProcessing && !error) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-center text-gray-500">
          <svg
            className="w-16 h-16 mx-auto mb-4 text-gray-700"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
            />
          </svg>
          <p className="text-lg font-medium mb-2">Ready to transcribe</p>
          <p className="text-sm">Click "Start Recording" to begin voice transcription</p>
        </div>
      </div>
    );
  }

  // Use the existing MessageList component for displaying transcripts
  return (
    <MessageList 
      messages={transcripts}
      isLoading={isProcessing}
      error={error}
    />
  );
}