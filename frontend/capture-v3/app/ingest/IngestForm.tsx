'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { documentSchema, documentTypes, type DocumentFormData } from '@/app/lib/schemas';

interface IngestFormProps {
  submitAction: (formData: FormData) => Promise<{ success: boolean; message: string; docId?: string }>;
}

export default function IngestForm({ submitAction }: IngestFormProps) {
  const [submitStatus, setSubmitStatus] = useState<{ type: 'success' | 'error' | null; message: string }>({
    type: null,
    message: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset,
  } = useForm<DocumentFormData>({
    resolver: zodResolver(documentSchema),
    defaultValues: {
      type: 'general_note',
      tags: '',
    },
  });

  const onSubmit = async (data: DocumentFormData) => {
    setIsSubmitting(true);
    setSubmitStatus({ type: null, message: '' });

    // Convert to FormData
    const formData = new FormData();
    formData.append('type', data.type);
    formData.append('title', data.title);
    formData.append('content', data.content);
    formData.append('tags', data.tags || '');
    formData.append('source_url', data.source_url || '');
    formData.append('link_to_doc_id', data.link_to_doc_id || '');

    try {
      const result = await submitAction(formData);
      
      if (result.success) {
        setSubmitStatus({ type: 'success', message: result.message });
        reset();
      } else {
        setSubmitStatus({ type: 'error', message: result.message });
      }
    } catch (error) {
      setSubmitStatus({ type: 'error', message: 'An unexpected error occurred' });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      {/* Document Type */}
      <div>
        <label htmlFor="type" className="block text-sm font-medium mb-1 text-gray-300">
          Document Type
        </label>
        <select
          {...register('type')}
          id="type"
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
        >
          {Object.entries(documentTypes).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        {errors.type && <p className="text-red-400 text-sm mt-1">{errors.type.message}</p>}
      </div>

      {/* Title */}
      <div>
        <label htmlFor="title" className="block text-sm font-medium mb-1 text-gray-300">
          Title <span className="text-red-400">*</span>
        </label>
        <input
          {...register('title')}
          type="text"
          id="title"
          maxLength={255}
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
          placeholder="Enter document title"
        />
        {errors.title && <p className="text-red-400 text-sm mt-1">{errors.title.message}</p>}
      </div>

      {/* Content */}
      <div>
        <label htmlFor="content" className="block text-sm font-medium mb-1 text-gray-300">
          Content <span className="text-red-400">*</span>
        </label>
        <textarea
          {...register('content')}
          id="content"
          rows={8}
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
          placeholder="Enter document content"
        />
        {errors.content && <p className="text-red-400 text-sm mt-1">{errors.content.message}</p>}
      </div>

      {/* Tags */}
      <div>
        <label htmlFor="tags" className="block text-sm font-medium mb-1 text-gray-300">
          Tags
        </label>
        <input
          {...register('tags')}
          type="text"
          id="tags"
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
          placeholder="Enter tags separated by commas"
        />
        <p className="text-gray-400 text-sm mt-1">Enter tags separated by commas (max 20 tags)</p>
        {errors.tags && <p className="text-red-400 text-sm mt-1">{errors.tags.message}</p>}
      </div>

      {/* Source URL */}
      <div>
        <label htmlFor="source_url" className="block text-sm font-medium mb-1 text-gray-300">
          Source URL
        </label>
        <input
          {...register('source_url')}
          type="url"
          id="source_url"
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
          placeholder="https://example.com"
        />
        {errors.source_url && <p className="text-red-400 text-sm mt-1">{errors.source_url.message}</p>}
      </div>

      {/* Link to Doc ID */}
      <div>
        <label htmlFor="link_to_doc_id" className="block text-sm font-medium mb-1 text-gray-300">
          Link to Document ID
        </label>
        <input
          {...register('link_to_doc_id')}
          type="text"
          id="link_to_doc_id"
          disabled={isSubmitting}
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-900 disabled:cursor-not-allowed"
          placeholder="Optional: ID of related document"
        />
        {errors.link_to_doc_id && <p className="text-red-400 text-sm mt-1">{errors.link_to_doc_id.message}</p>}
      </div>

      {/* Status Messages */}
      {submitStatus.type && (
        <div
          className={`p-3 rounded-md ${
            submitStatus.type === 'success' ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'
          }`}
        >
          {submitStatus.message}
        </div>
      )}

      {/* Submit Button */}
      <button
        type="submit"
        disabled={isSubmitting}
        className={`w-full py-2 px-4 rounded-md font-medium text-white transition-colors ${
          isSubmitting
            ? 'bg-gray-600 cursor-not-allowed'
            : 'bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500'
        }`}
      >
        {isSubmitting ? 'Submitting...' : 'Save Note'}
      </button>
    </form>
  );
}