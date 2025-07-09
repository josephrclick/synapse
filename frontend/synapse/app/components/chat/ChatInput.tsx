'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ChatFormData } from '@/app/types/chat';
import AdvancedSettings from './AdvancedSettings';

const chatFormSchema = z.object({
  query: z.string()
    .min(1, 'Please enter a message')
    .max(1000, 'Message must be less than 1000 characters')
    .trim(),
  contextLimit: z.number()
    .min(1)
    .max(20)
    .default(5),
});

interface ChatInputProps {
  onSubmit: (query: string, contextLimit: number) => Promise<void>;
  isLoading: boolean;
  contextLimit: number;
  onContextLimitChange: (limit: number) => void;
}

export default function ChatInput({ 
  onSubmit, 
  isLoading, 
  contextLimit,
  onContextLimitChange 
}: ChatInputProps) {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
    setValue,
    watch,
  } = useForm<ChatFormData>({
    resolver: zodResolver(chatFormSchema),
    defaultValues: {
      query: '',
      contextLimit: contextLimit,
    },
  });

  const currentContextLimit = watch('contextLimit');

  const onSubmitForm = async (data: ChatFormData) => {
    await onSubmit(data.query, data.contextLimit);
    reset({ query: '', contextLimit: data.contextLimit });
  };

  const handleContextLimitUpdate = (newLimit: number) => {
    setValue('contextLimit', newLimit);
    onContextLimitChange(newLimit);
  };

  return (
    <form onSubmit={handleSubmit(onSubmitForm)} className="border-t border-gray-800 p-4">
      <div className="space-y-2">
        <div className="flex space-x-2">
          <input
            {...register('query')}
            type="text"
            placeholder="Ask a question about your knowledge..."
            disabled={isLoading}
            className="flex-1 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-gray-100 
                     placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500
                     disabled:bg-gray-900 disabled:cursor-not-allowed transition-all"
            maxLength={1000}
          />
          
          <button
            type="submit"
            disabled={isLoading}
            className={`px-6 py-2 rounded-lg font-medium text-white transition-all ${
              isLoading
                ? 'bg-gray-600 cursor-not-allowed'
                : 'bg-cyan-600 hover:bg-cyan-700 focus:outline-none focus:ring-2 focus:ring-cyan-500 hover:shadow-lg hover:shadow-cyan-500/25'
            }`}
          >
            {isLoading ? 'Sending...' : 'Send'}
          </button>
        </div>
        
        {errors.query && (
          <p className="text-red-400 text-sm">{errors.query.message}</p>
        )}
        
        <AdvancedSettings
          contextLimit={currentContextLimit}
          onContextLimitChange={handleContextLimitUpdate}
          disabled={isLoading}
        />
      </div>
    </form>
  );
}