export interface Source {
  id: string;
  title: string;
  content: string;
  type?: string;
}

export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  sources?: Source[];
  queryTimeMs?: number;
  timestamp: Date;
  error?: string;
}

export interface ChatState {
  messages: Message[];
  isLoading: boolean;
  error: string | null;
  contextLimit: number;
}

export type ChatAction =
  | { type: 'ADD_USER_MESSAGE'; payload: { content: string } }
  | { type: 'ADD_ASSISTANT_MESSAGE'; payload: { content: string; sources?: Source[]; queryTimeMs?: number } }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_CONTEXT_LIMIT'; payload: number }
  | { type: 'UPDATE_MESSAGE'; payload: { id: string; updates: Partial<Message> } }
  | { type: 'CLEAR_MESSAGES' };

export interface ChatRequest {
  query: string;
  context_limit?: number;
}

export interface ChatResponse {
  answer: string;
  sources: Source[];
  query_time_ms: number;
}

export interface ChatServiceResponse {
  data?: ChatResponse;
  error?: string;
  latency?: number;
}

export interface ChatFormData {
  query: string;
  contextLimit: number;
}