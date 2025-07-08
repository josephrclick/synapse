import { documentSchema, type IngestionResponse } from '@/app/lib/schemas';
import IngestForm from './IngestForm';

async function submitDocument(formData: FormData): Promise<{ success: boolean; message: string; docId?: string }> {
  'use server';

  // Parse form data
  const rawData = {
    type: formData.get('type') as string,
    title: formData.get('title') as string,
    content: formData.get('content') as string,
    tags: formData.get('tags') as string,
    source_url: formData.get('source_url') as string,
    link_to_doc_id: formData.get('link_to_doc_id') as string,
  };

  // Validate with Zod
  const validation = documentSchema.safeParse(rawData);
  
  if (!validation.success) {
    return {
      success: false,
      message: validation.error.errors[0].message,
    };
  }

  // Prepare API payload
  const payload = {
    type: validation.data.type,
    title: validation.data.title,
    content: validation.data.content,
    tags: validation.data.tags,
    source_url: validation.data.source_url || undefined,
    link_to_doc_id: validation.data.link_to_doc_id || undefined,
  };

  try {
    // Make API request
    const response = await fetch(`${process.env.BACKEND_URL}/api/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': process.env.BACKEND_API_KEY!,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const error = await response.json();
      return {
        success: false,
        message: error.detail || 'Failed to submit document',
      };
    }

    const data: IngestionResponse = await response.json();
    
    return {
      success: true,
      message: data.message || 'Note submitted for processing!',
      docId: data.doc_id,
    };
  } catch (error) {
    console.error('Error submitting document:', error);
    return {
      success: false,
      message: 'Failed to connect to the server. Please try again.',
    };
  }
}

export default function IngestPage() {
  return (
    <div className="container mx-auto p-4 max-w-2xl">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold mb-2 text-gray-100">Expand Your Network</h1>
        <p className="text-gray-400">Add new knowledge to your neural database</p>
      </div>
      <IngestForm submitAction={submitDocument} />
    </div>
  );
}