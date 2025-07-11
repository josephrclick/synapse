'use client';

interface VoiceToggleProps {
  isRecording: boolean;
  isProcessing: boolean;
  onToggle: () => void;
  disabled?: boolean;
}

export default function VoiceToggle({
  isRecording,
  isProcessing,
  onToggle,
  disabled = false,
}: VoiceToggleProps) {
  const getButtonText = () => {
    if (isProcessing) return 'Initializing...';
    if (isRecording) return 'Stop Recording';
    return 'Start Recording';
  };

  const getButtonClasses = () => {
    const baseClasses = 'flex items-center justify-center gap-3 px-6 py-4 rounded-lg font-medium transition-all transform active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed';
    
    if (isRecording) {
      return `${baseClasses} bg-red-600 hover:bg-red-700 text-white animate-pulse`;
    }
    
    return `${baseClasses} bg-zinc-800 hover:bg-zinc-700 text-white`;
  };

  const getMicrophoneIcon = () => {
    if (isProcessing) {
      // Loading spinner
      return (
        <div className="w-5 h-5">
          <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
        </div>
      );
    }
    
    // Microphone icon
    return (
      <svg
        className={`w-5 h-5 ${isRecording ? 'animate-pulse' : ''}`}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
        />
      </svg>
    );
  };

  return (
    <div className="p-4 border-t border-gray-800">
      <div className="flex flex-col items-center gap-4">
        <button
          onClick={onToggle}
          disabled={disabled || isProcessing}
          className={getButtonClasses()}
        >
          {getMicrophoneIcon()}
          <span>{getButtonText()}</span>
        </button>
        
        {isRecording && (
          <div className="flex items-center gap-2 text-red-500 text-sm">
            <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
            <span>Recording in progress...</span>
          </div>
        )}
        
        <div className="text-xs text-zinc-600 text-center">
          <div>⚠️ WARNING: This PoC exposes the API key in the browser. NOT FOR PRODUCTION USE!</div>
          <div className="mt-1">
            To use this feature, add your Deepgram API key to <code className="text-zinc-500">.env.local</code>
          </div>
          <div className="mt-1">
            Get a free API key at <a href="https://deepgram.com" target="_blank" rel="noopener noreferrer" className="text-cyan-500 hover:text-cyan-400">deepgram.com</a>
          </div>
        </div>
      </div>
    </div>
  );
}