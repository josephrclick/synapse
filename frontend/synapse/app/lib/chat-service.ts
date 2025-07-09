import { ChatRequest, ChatResponse, ChatServiceResponse } from '@/app/types/chat';

export async function sendChatQuery(
  query: string,
  contextLimit: number = 5,
  signal?: AbortSignal
): Promise<ChatServiceResponse> {
  const startTime = Date.now();
  
  try {
    const request: ChatRequest = {
      query: query.trim(),
      context_limit: contextLimit,
    };

    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
      signal,
    });

    const latency = Date.now() - startTime;

    if (!response.ok) {
      let errorMessage = `Server error: ${response.status}`;
      
      try {
        const errorData = await response.json();
        if (errorData.detail) {
          errorMessage = typeof errorData.detail === 'string' 
            ? errorData.detail 
            : JSON.stringify(errorData.detail);
        }
      } catch {
        // If parsing fails, use the default error message
      }

      return {
        error: errorMessage,
        latency,
      };
    }

    const data: ChatResponse = await response.json();
    
    return {
      data,
      latency,
    };
  } catch (error) {
    const latency = Date.now() - startTime;
    
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      return {
        error: 'Unable to connect to the server. Please ensure the backend is running.',
        latency,
      };
    }
    
    return {
      error: error instanceof Error ? error.message : 'An unexpected error occurred',
      latency,
    };
  }
}