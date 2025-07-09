import { z } from 'zod';

export const documentTypes = {
  job_post: 'Job Post',
  interview_note: 'Interview Note',
  general_note: 'General Note',
  article: 'Article',
  meeting_note: 'Meeting Note',
  other: 'Other',
} as const;

export const documentSchema = z.object({
  type: z.enum(['job_post', 'interview_note', 'general_note', 'article', 'meeting_note', 'other']),
  title: z.string().min(1, 'Title is required').max(255, 'Title must be 255 characters or less').trim(),
  content: z.string().min(1, 'Content is required'),
  tags: z.string()
    .optional()
    .transform((val) => {
      if (!val) return [];
      return val.split(',').map(tag => tag.trim()).filter(Boolean);
    })
    .refine((tags) => tags.length <= 20, 'Maximum 20 tags allowed'),
  source_url: z.string()
    .optional()
    .refine((url) => {
      if (!url) return true;
      try {
        const parsed = new URL(url);
        return parsed.protocol === 'http:' || parsed.protocol === 'https:';
      } catch {
        return false;
      }
    }, 'Must be a valid HTTP(S) URL'),
  link_to_doc_id: z.string().optional(),
});

export type DocumentFormData = z.infer<typeof documentSchema>;

export interface IngestionResponse {
  doc_id: string;
  status: string;
  message: string;
}