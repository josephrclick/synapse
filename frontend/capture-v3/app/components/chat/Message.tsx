'use client';

import { useMemo } from 'react';
import DOMPurify from 'dompurify';
import { Message as MessageType } from '@/app/types/chat';
import SourcesAccordion from './SourcesAccordion';

interface MessageProps {
  message: MessageType;
}

// Configure DOMPurify with strict allowlist for chat context
const DOMPURIFY_CONFIG = {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'code', 'pre', 'br', 'p', 'ul', 'ol', 'li'],
  ALLOWED_ATTR: ['href', 'target', 'rel'],
  ALLOW_DATA_ATTR: false,
  ADD_ATTR: ['target'], // Force target="_blank" on links
  ADD_TAGS: [], // No custom tags
  FORCE_BODY: true, // Wrap content in body tag for consistent parsing
};

export default function Message({ message }: MessageProps) {
  const isUser = message.role === 'user';
  
  // Sanitize assistant messages to prevent XSS
  const sanitizedContent = useMemo(() => {
    if (isUser) {
      // User messages are displayed as plain text
      return message.content;
    }
    // Assistant messages may contain formatting, sanitize them
    return DOMPurify.sanitize(message.content, DOMPURIFY_CONFIG);
  }, [message.content, isUser]);
  
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[80%] ${isUser ? 'order-2' : 'order-1'}`}>
        <div
          className={`rounded-lg px-4 py-2 ${
            isUser
              ? 'bg-blue-600 text-white'
              : 'bg-gray-800 text-gray-100'
          }`}
        >
          {isUser ? (
            <p className="whitespace-pre-wrap">{sanitizedContent}</p>
          ) : (
            <div 
              className="whitespace-pre-wrap" 
              dangerouslySetInnerHTML={{ __html: sanitizedContent }}
            />
          )}
        </div>
        
        {!isUser && message.sources && message.sources.length > 0 && (
          <div className="mt-2">
            <SourcesAccordion sources={message.sources} />
          </div>
        )}
        
        {!isUser && message.queryTimeMs !== undefined && (
          <p className="text-xs text-gray-500 mt-1 px-1">
            Generated in {message.queryTimeMs}ms
          </p>
        )}
      </div>
    </div>
  );
}