'use client';

import { useState } from 'react';

interface AdvancedSettingsProps {
  contextLimit: number;
  onContextLimitChange: (limit: number) => void;
  disabled?: boolean;
}

export default function AdvancedSettings({ 
  contextLimit, 
  onContextLimitChange,
  disabled = false 
}: AdvancedSettingsProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="text-sm">
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        disabled={disabled}
        className="flex items-center space-x-1 text-gray-400 hover:text-gray-300 
                   transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <span className={`transform transition-transform ${isOpen ? 'rotate-90' : ''}`}>
          ▶
        </span>
        <span>Advanced Settings</span>
      </button>
      
      {isOpen && (
        <div className="mt-2 p-3 bg-gray-800 rounded-lg">
          <div>
            <label htmlFor="contextLimit" className="block text-gray-300 mb-1">
              Context Documents Limit
            </label>
            <div className="flex items-center space-x-2">
              <input
                id="contextLimit"
                type="range"
                min="1"
                max="20"
                value={contextLimit}
                onChange={(e) => onContextLimitChange(Number(e.target.value))}
                disabled={disabled}
                className="flex-1"
              />
              <span className="text-gray-300 w-8 text-center">{contextLimit}</span>
            </div>
            <p className="text-gray-500 text-xs mt-1">
              Number of documents to retrieve for context (1-20)
            </p>
          </div>
        </div>
      )}
    </div>
  );
}