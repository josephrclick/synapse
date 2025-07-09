'use client';

import { useRef, useCallback } from 'react';
import { Virtuoso, VirtuosoHandle } from 'react-virtuoso';
import { Message as MessageType } from '@/app/types/chat';
import Message from './Message';

interface MessageListProps {
  messages: MessageType[];
  isLoading: boolean;
  error: string | null;
}

export default function MessageList({ messages, isLoading, error }: MessageListProps) {
  const virtuosoRef = useRef<VirtuosoHandle>(null);

  // Item renderer for virtualization
  const itemContent = useCallback((index: number) => {
    const message = messages[index];
    return (
      <div className="px-4 py-2">
        <Message key={message.id} message={message} />
      </div>
    );
  }, [messages]);

  // Footer component for loading and error states
  const Footer = useCallback(() => (
    <>
      {isLoading && (
        <div className="flex items-center space-x-2 text-gray-400 p-4">
          <div className="animate-pulse">
            <div className="flex space-x-1">
              <div className="w-2 h-2 bg-gray-600 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
              <div className="w-2 h-2 bg-gray-600 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
              <div className="w-2 h-2 bg-gray-600 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
            </div>
          </div>
          <span className="text-sm">Thinking...</span>
        </div>
      )}
      
      {error && (
        <div className="bg-red-900 bg-opacity-50 border border-red-700 rounded-md p-3 m-4">
          <p className="text-red-300 text-sm">{error}</p>
        </div>
      )}
    </>
  ), [isLoading, error]);

  // Empty state when no messages
  if (messages.length === 0 && !isLoading) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-center text-gray-500">
          <p>No messages yet. Start a conversation!</p>
        </div>
      </div>
    );
  }

  return (
    <Virtuoso
      ref={virtuosoRef}
      className="flex-1"
      data={messages}
      itemContent={itemContent}
      followOutput="smooth"
      initialTopMostItemIndex={messages.length > 0 ? messages.length - 1 : 0}
      components={{
        Footer
      }}
    />
  );
}