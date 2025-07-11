'use client';

import { useDeepgramRecording } from '@/app/lib/hooks/useDeepgramRecording';

/**
 * DeepgramPocButton - Push-to-talk voice transcription component
 * 
 * WARNING: This is a proof-of-concept for learning purposes only!
 * The API key is exposed in the browser - DO NOT USE IN PRODUCTION!
 * 
 * For production use:
 * - Move API key to backend
 * - Implement server-side WebSocket proxy
 * - Add comprehensive error handling
 */
export default function DeepgramPocButton() {
  const {
    isRecording,
    transcript,
    error,
    isSupported,
    startRecording,
    stopRecording,
  } = useDeepgramRecording();

  if (!isSupported) {
    return (
      <div className="text-red-500 text-sm">
        Browser does not support audio recording
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <button
        onPointerDown={startRecording}
        onPointerUp={stopRecording}
        onPointerLeave={stopRecording} // Safety: stop if pointer leaves button
        disabled={!isSupported}
        className={`
          px-6 py-3 rounded-lg font-medium transition-all
          ${isRecording 
            ? 'bg-red-600 hover:bg-red-700 text-white scale-95' 
            : 'bg-zinc-800 hover:bg-zinc-700 text-white'
          }
          disabled:opacity-50 disabled:cursor-not-allowed
          select-none
        `}
      >
        {isRecording ? '🎤 Recording... (release to stop)' : '🎙️ Push to Talk'}
      </button>

      {error && (
        <div className="text-red-500 text-sm">
          Error: {error}
        </div>
      )}

      {transcript && (
        <div className="p-4 bg-zinc-900 rounded-lg">
          <p className="text-sm text-zinc-300">Transcript:</p>
          <p className="text-white mt-1">{transcript}</p>
        </div>
      )}

      <div className="text-xs text-zinc-600">
        ⚠️ WARNING: This PoC exposes the API key in the browser. NOT FOR PRODUCTION USE!
      </div>
    </div>
  );
}