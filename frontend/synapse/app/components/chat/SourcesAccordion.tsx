'use client';

import { useState } from 'react';
import { Source } from '@/app/types/chat';

interface SourcesAccordionProps {
  sources: Source[];
  defaultOpen?: boolean;
}

export default function SourcesAccordion({ sources, defaultOpen = false }: SourcesAccordionProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <div className="text-sm">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-2 text-gray-400 hover:text-gray-300 transition-colors"
      >
        <span className={`transform transition-transform ${isOpen ? 'rotate-90' : ''}`}>
          ▶
        </span>
        <span>Sources ({sources.length})</span>
      </button>
      
      {isOpen && (
        <div className="mt-2 space-y-2 pl-6">
          {sources.map((source) => (
            <div key={source.id} className="bg-gray-800 bg-opacity-50 rounded p-3">
              <h4 className="font-medium text-gray-200 mb-1">{source.title}</h4>
              <p className="text-gray-400 text-xs line-clamp-3">{source.content}</p>
              {source.type && (
                <span className="inline-block mt-1 px-2 py-0.5 text-xs bg-gray-700 text-gray-300 rounded">
                  {source.type}
                </span>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}