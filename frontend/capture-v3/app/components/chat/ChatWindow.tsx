'use client';

import { useReducer, useCallback, useRef } from 'react';
import { chatReducer, initialChatState } from '@/app/lib/chat-reducer';
import { sendChatQuery } from '@/app/lib/chat-service';
import MessageList from './MessageList';
import ChatInput from './ChatInput';

export default function ChatWindow() {
  const [state, dispatch] = useReducer(chatReducer, initialChatState);
  const abortControllerRef = useRef<AbortController | null>(null);

  const handleSubmit = useCallback(async (query: string, contextLimit: number) => {
    // Cancel any previous, still-running request. This is the correct pattern.
    abortControllerRef.current?.abort();

    // Create a new controller for the new request and store its reference.
    const controller = new AbortController();
    abortControllerRef.current = controller;

    // Add user message
    dispatch({ type: 'ADD_USER_MESSAGE', payload: { content: query } });
    
    // Set loading state
    dispatch({ type: 'SET_LOADING', payload: true });
    
    try {
      // Make API call with abort signal
      const response = await sendChatQuery(query, contextLimit, controller.signal);
      
      if (response.error) {
        dispatch({ type: 'SET_ERROR', payload: response.error });
      } else if (response.data) {
        // Add assistant response
        dispatch({
          type: 'ADD_ASSISTANT_MESSAGE',
          payload: {
            content: response.data.answer,
            sources: response.data.sources,
            queryTimeMs: response.data.query_time_ms,
          },
        });
      }
    } catch (error) {
      // Correctly ignore the error for intentional cancellations.
      if (error instanceof Error && error.name === 'AbortError') {
        console.log('Request successfully cancelled.');
        return; // Stop execution
      }
      dispatch({ 
        type: 'SET_ERROR', 
        payload: error instanceof Error ? error.message : 'An unexpected error occurred' 
      });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  }, []);

  const handleContextLimitChange = useCallback((limit: number) => {
    dispatch({ type: 'SET_CONTEXT_LIMIT', payload: limit });
  }, []);

  return (
    <div className="flex flex-col h-full max-w-4xl mx-auto p-4">
      <header className="mb-4 text-center flex-shrink-0">
        <div className="flex items-center justify-center space-x-2 mb-2">
          <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse"></div>
          <h1 className="text-3xl font-bold text-gray-100">Neural Chat</h1>
          <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse" style={{ animationDelay: '0.5s' }}></div>
        </div>
        <p className="text-gray-400">Connect with your knowledge network</p>
      </header>
      
      <div className="flex-1 flex flex-col bg-gray-900 rounded-lg overflow-hidden min-h-0">
        <MessageList 
          messages={state.messages} 
          isLoading={state.isLoading}
          error={state.error}
        />
        
        <ChatInput
          onSubmit={handleSubmit}
          isLoading={state.isLoading}
          contextLimit={state.contextLimit}
          onContextLimitChange={handleContextLimitChange}
        />
      </div>
    </div>
  );
}