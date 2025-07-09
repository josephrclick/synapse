import { type NextRequest } from 'next/server';

// These environment variables are now SERVER-SIDE ONLY.
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8101';
const API_KEY = process.env.BACKEND_API_KEY || '';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    // Create the request to the real backend
    const proxyRequest = new Request(`${BACKEND_URL}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': API_KEY, // The secret key is added here, on the server.
      },
      body: JSON.stringify(body),
    });

    // Forward the request and return the response directly.
    // This is a simple, effective proxy that doesn't need streaming logic for the MVP.
    return await fetch(proxyRequest);

  } catch (error) {
    console.error('API Proxy Error:', error);
    return new Response('An internal server error occurred.', { status: 500 });
  }
}