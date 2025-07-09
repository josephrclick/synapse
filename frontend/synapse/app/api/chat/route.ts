import { type NextRequest } from 'next/server';

// These environment variables are now SERVER-SIDE ONLY.
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8101';
const API_KEY = process.env.BACKEND_API_KEY || '';

console.log('Backend URL:', BACKEND_URL);
console.log('API Key configured:', API_KEY ? 'Yes' : 'No');

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
    const backendResponse = await fetch(proxyRequest);
    
    // Log the response status for debugging
    console.log('Backend response status:', backendResponse.status);
    console.log('Backend response headers:', Object.fromEntries(backendResponse.headers.entries()));
    
    if (!backendResponse.ok) {
      const responseText = await backendResponse.text();
      console.error('Backend error response:', responseText);
      
      // Return a new response with the error details
      return new Response(responseText, {
        status: backendResponse.status,
        statusText: backendResponse.statusText,
        headers: {
          'Content-Type': 'application/json',
        },
      });
    }
    
    // For successful responses, read the body and create a new response
    const responseData = await backendResponse.json();
    return new Response(JSON.stringify(responseData), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
      },
    });

  } catch (error) {
    console.error('API Proxy Error:', error);
    return new Response('An internal server error occurred.', { status: 500 });
  }
}