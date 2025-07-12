'use client';

import { useState } from 'react';

export default function TestWS() {
  const [output, setOutput] = useState<string[]>([]);

  const addOutput = (message: string) => {
    setOutput(prev => [...prev, message]);
  };

  const testConnection = () => {
    setOutput(['Testing connection...']);
    
    const apiKey = 'db253803dcb76d691744e50ccae23d7a03a21032';
    
    // Test 1: Minimal parameters
    addOutput('Test 1: Minimal parameters with token in URL');
    const wsUrl1 = `wss://api.deepgram.com/v1/listen?token=${apiKey}`;
    addOutput(`URL: ${wsUrl1.replace(apiKey, 'REDACTED')}`);
    
    try {
      const ws1 = new WebSocket(wsUrl1);
      
      ws1.onopen = function() {
        addOutput('✅ Test 1 Connected!');
        ws1.close();
      };
      
      ws1.onerror = function(error) {
        addOutput('❌ Test 1 Error');
        console.error('Test 1 error:', error);
      };
      
      ws1.onclose = function(event) {
        addOutput(`Test 1 Closed: Code ${event.code}, Reason: ${event.reason || 'none'}`);
      };
    } catch (error: any) {
      addOutput(`❌ Test 1 Exception: ${error.message}`);
    }
    
    // Test 2: With encoding parameter
    setTimeout(() => {
      addOutput('\nTest 2: With encoding parameter');
      const wsUrl2 = `wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&token=${apiKey}`;
      addOutput(`URL: ${wsUrl2.replace(apiKey, 'REDACTED')}`);
      
      try {
        const ws2 = new WebSocket(wsUrl2);
        
        ws2.onopen = function() {
          addOutput('✅ Test 2 Connected!');
          ws2.close();
        };
        
        ws2.onerror = function(error) {
          addOutput('❌ Test 2 Error');
        };
        
        ws2.onclose = function(event) {
          addOutput(`Test 2 Closed: Code ${event.code}`);
        };
      } catch (error: any) {
        addOutput(`❌ Test 2 Exception: ${error.message}`);
      }
    }, 1000);
    
    // Test 3: Using Authorization header format
    setTimeout(() => {
      addOutput('\nTest 3: Using key parameter instead of token');
      const wsUrl3 = `wss://api.deepgram.com/v1/listen?key=${apiKey}`;
      addOutput(`URL: ${wsUrl3.replace(apiKey, 'REDACTED')}`);
      
      try {
        const ws3 = new WebSocket(wsUrl3);
        
        ws3.onopen = function() {
          addOutput('✅ Test 3 Connected!');
          ws3.close();
        };
        
        ws3.onerror = function(error) {
          addOutput('❌ Test 3 Error');
        };
        
        ws3.onclose = function(event) {
          addOutput(`Test 3 Closed: Code ${event.code}`);
        };
      } catch (error: any) {
        addOutput(`❌ Test 3 Exception: ${error.message}`);
      }
    }, 2000);
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl mb-4">Deepgram WebSocket Test - Final</h1>
      <button 
        onClick={testConnection}
        className="bg-blue-500 px-4 py-2 rounded mb-4"
      >
        Test Connection
      </button>
      <div className="bg-gray-800 p-4 rounded">
        {output.map((line, i) => (
          <p key={i} className={line.includes('✅') ? 'text-green-400' : line.includes('❌') ? 'text-red-400' : ''}>
            {line}
          </p>
        ))}
      </div>
    </div>
  );
}