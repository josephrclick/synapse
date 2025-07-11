# Voice Transcription Feature

This is a proof-of-concept voice transcription feature using Deepgram's real-time speech-to-text API.

## Setup Instructions

### 1. Get a Deepgram API Key

1. Visit [deepgram.com](https://deepgram.com)
2. Sign up for a free account
3. Navigate to your API Keys section
4. Create a new API key

### 2. Configure Environment Variables

1. Copy the example environment file (if you haven't already):
   ```bash
   cp .env.local.example .env.local
   ```

2. Edit `.env.local` and add your Deepgram API key:
   ```
   NEXT_PUBLIC_DEEPGRAM_API_KEY=your-actual-deepgram-api-key-here
   ```

3. Restart the Next.js development server:
   ```bash
   npm run dev
   ```

## Usage

1. Navigate to http://localhost:8100/voice
2. Click "Start Recording" to begin voice transcription
3. Speak into your microphone
4. Click "Stop Recording" to end transcription
5. Your transcribed text will appear in the message list

## Features

- Toggle-based recording (click to start/stop)
- Real-time transcription display
- Visual recording indicators
- Browser compatibility checking
- Error handling for API issues

## Security Warning

⚠️ **IMPORTANT**: This implementation exposes the API key in the browser and is NOT suitable for production use.

For production deployment, you should:
- Implement a backend WebSocket proxy
- Keep the API key server-side only
- Add authentication and rate limiting

## Browser Support

- Chrome/Edge: Full support
- Firefox: Full support
- Safari: Limited support (iOS 15+ required)

## Troubleshooting

### "Invalid Deepgram API key" Error
- Verify your API key is correct in `.env.local`
- Make sure you've restarted the dev server after adding the key
- Check that your Deepgram account is active

### "Browser does not support audio recording"
- Ensure you're using a modern browser
- Check that your browser has microphone permissions
- For Safari iOS, ensure you're on version 15 or higher

### No audio is being captured
- Check browser microphone permissions
- Ensure no other application is using the microphone
- Try refreshing the page and granting permissions again