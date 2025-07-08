# Build Ticket: Deepgram JavaScript SDK - Interview Prep PoC

**Project:** Synapse

**Sprint:** Interview Prep Mini-Sprint

**Ticket ID:** `C3-S3-T1-DEEPGRAM-POC`

**Priority:** **URGENT** (Time-sensitive for interview prep)

## 1\. Objective

To rapidly implement a "quick and dirty" proof-of-concept using **Deepgram's live streaming JavaScript SDK**. The primary goal is to gain hands-on experience with the client-side library to prepare for a technical interview. This is a learning exercise, not a production feature.

> **Developer's Note:** Consult Context7 for the latest Deepgram JavaScript SDK documentation and code examples before building. Search for "Deepgram JavaScript live transcription" or "MediaRecorder WebSocket" for relevant patterns.

## 2\. Chosen Architecture (Client-Side Streaming)

We will implement the entire feature on the frontend to maximize interaction with the target SDK.

-   **Audio Capture:** Use the browser's `MediaRecorder` API.
    
-   **Transcription:** Establish a direct WebSocket connection from the browser to Deepgram's live transcription service using their SDK.
    
-   **Security:** **Deliberate Shortcut:** For this temporary PoC, the Deepgram API key will be stored in a `NEXT_PUBLIC_` environment variable and used on the client. **This is insecure and must not be done in production**, but it is the fastest way to get a working prototype for this learning exercise.
    

## 3\. Implementation Plan

### Phase 1: Create the Voice Capture Component

**File to Create:** `frontend/capture-v3/app/components/voice/DeepgramPocButton.tsx`

1.  **Install SDK:** In your terminal, run `npm install @deepgram/sdk`.
    
2.  **Component Structure:** Create a simple React client component (`'use client'`). It should contain a single button.
    
3.  **State Management:** Use `useState` to track `isRecording` and `transcript`.
    
4.  **Core Logic:**
    
    -   Use `useRef` to hold references to the `MediaRecorder` and the `LiveClient` connection from the Deepgram SDK.
        
    -   **On Button `onMouseDown`:**
        
        -   Request microphone permissions: `navigator.mediaDevices.getUserMedia({ audio: true })`.
            
        -   Initialize the Deepgram client: `createClient(YOUR_API_KEY)`.
            
        -   Open a live connection: `deepgram.listen.live(...)`.
            
        -   Set up event listeners for the connection (`open`, `transcript`, `close`, `error`).
            
        -   Inside the `open` event listener, create the `MediaRecorder` and set its `ondataavailable` handler to send audio chunks to the Deepgram connection (`connection.send(data)`).
            
        -   Start the `MediaRecorder`.
            
    -   **On Button `onMouseUp`:**
        
        -   Stop the `MediaRecorder`.
            
        -   Close the Deepgram connection (`connection.requestClose()`).
            
5.  **Transcript Handling:**
    
    -   In the `transcript` event listener from the SDK, check for `data.is_final && data.speech_final`.
        
    -   When you receive a final transcript, update the `transcript` state.
        
6.  **Display:** Render the `transcript` state in a simple `<p>` tag below the button so you can see the result.
    

### Phase 2: Integration

1.  **Add Component to UI:** Place your new `<DeepgramPocButton />` component on the main page (`/frontend/capture-v3/app/page.tsx`).
    
2.  **Configure Environment:** Add your Deepgram API key to `/frontend/capture-v3/.env.local`:
    
    ```
    NEXT_PUBLIC_DEEPGRAM_API_KEY=your-deepgram-api-key-here
    
    ```
    

## 4\. "Quick & Dirty" - What We Are **NOT** Doing

To ensure this is achievable in one session, we will strictly avoid:

-   **NO Backend Changes:** We will not create any new FastAPI endpoints.
    
-   **NO Database Interaction:** We will not save the transcript to Synapse. The goal is to see it work in the UI, not to persist it.
    
-   **NO Complex UI:** A simple button and a paragraph tag for the output is sufficient.
    
-   **NO Advanced Error Handling:** We will rely on `console.log` and the browser's developer tools for debugging.
    

## 5\. Acceptance Criteria

-   \[ \] A "Push to Talk" button is visible in the Synapse UI.
    
-   \[ \] Clicking and holding the button activates the browser's microphone.
    
-   \[ \] While holding the button, audio is streamed to Deepgram.
    
-   \[ \] Upon releasing the button, the final transcribed text from the spoken audio is displayed on the screen below the button.