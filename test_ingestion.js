// Test script to verify document ingestion via frontend server action

async function testIngestion() {
  try {
    // Simulate the frontend server action
    const response = await fetch('http://localhost:8101/api/documents', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': 'test-api-key-123'
      },
      body: JSON.stringify({
        type: 'note',
        title: 'Frontend Test Note',
        content: 'This is a test note submitted via simulated frontend action.',
        tags: ['frontend', 'test']
      })
    });

    if (!response.ok) {
      const error = await response.json();
      console.error('Error:', error);
      return;
    }

    const data = await response.json();
    console.log('Success:', data);
  } catch (error) {
    console.error('Fetch failed:', error);
  }
}

testIngestion();