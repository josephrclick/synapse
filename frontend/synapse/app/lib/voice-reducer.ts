import { Message } from '@/app/types/chat';

export interface VoiceState {
  transcripts: Message[];
  isRecording: boolean;
  isProcessing: boolean;
  error: string | null;
}

export type VoiceAction =
  | { type: 'ADD_TRANSCRIPT'; payload: { content: string } }
  | { type: 'SET_RECORDING'; payload: boolean }
  | { type: 'SET_PROCESSING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'CLEAR_TRANSCRIPTS' };

export const initialVoiceState: VoiceState = {
  transcripts: [],
  isRecording: false,
  isProcessing: false,
  error: null,
};

function generateMessageId(): string {
  return `voice_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

export function voiceReducer(state: VoiceState, action: VoiceAction): VoiceState {
  switch (action.type) {
    case 'ADD_TRANSCRIPT': {
      const newTranscript: Message = {
        id: generateMessageId(),
        role: 'user',
        content: action.payload.content,
        timestamp: new Date(),
      };
      return {
        ...state,
        transcripts: [...state.transcripts, newTranscript],
        error: null,
      };
    }

    case 'SET_RECORDING': {
      return {
        ...state,
        isRecording: action.payload,
      };
    }

    case 'SET_PROCESSING': {
      return {
        ...state,
        isProcessing: action.payload,
      };
    }

    case 'SET_ERROR': {
      return {
        ...state,
        error: action.payload,
        isRecording: false,
        isProcessing: false,
      };
    }

    case 'CLEAR_TRANSCRIPTS': {
      return {
        ...state,
        transcripts: [],
        error: null,
      };
    }

    default: {
      return state;
    }
  }
}