import { ChatState, ChatAction, Message } from '@/app/types/chat';

export const initialChatState: ChatState = {
  messages: [],
  isLoading: false,
  error: null,
  contextLimit: 5,
};

function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

export function chatReducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
    case 'ADD_USER_MESSAGE': {
      const newMessage: Message = {
        id: generateMessageId(),
        role: 'user',
        content: action.payload.content,
        timestamp: new Date(),
      };
      return {
        ...state,
        messages: [...state.messages, newMessage],
        error: null,
      };
    }

    case 'ADD_ASSISTANT_MESSAGE': {
      const newMessage: Message = {
        id: generateMessageId(),
        role: 'assistant',
        content: action.payload.content,
        sources: action.payload.sources,
        queryTimeMs: action.payload.queryTimeMs,
        timestamp: new Date(),
      };
      return {
        ...state,
        messages: [...state.messages, newMessage],
        isLoading: false,
        error: null,
      };
    }

    case 'SET_LOADING': {
      return {
        ...state,
        isLoading: action.payload,
      };
    }

    case 'SET_ERROR': {
      return {
        ...state,
        error: action.payload,
        isLoading: false,
      };
    }

    case 'SET_CONTEXT_LIMIT': {
      return {
        ...state,
        contextLimit: action.payload,
      };
    }

    case 'UPDATE_MESSAGE': {
      const { id, updates } = action.payload;
      return {
        ...state,
        messages: state.messages.map((msg) =>
          msg.id === id ? { ...msg, ...updates } : msg
        ),
      };
    }

    case 'CLEAR_MESSAGES': {
      return {
        ...state,
        messages: [],
        error: null,
      };
    }

    default: {
      return state;
    }
  }
}