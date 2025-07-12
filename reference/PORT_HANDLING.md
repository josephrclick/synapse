# Frontend Port Handling in Make Dev

The `make dev` command now includes interactive handling for port 8100 (frontend port) conflicts.

## How it works

1. **Backend ports (8101, 8102, 11434)**: Must be available. If any are in use, the script exits with an error.

2. **Frontend port (8100)**: If in use, you get an interactive prompt:
   ```
   ⚠️  Port 8100 is in use
   node      12345 user   23u  IPv4 0x1234567890abcdef      0t0  TCP *:8100 (LISTEN)
   
   Options:
     1) Stop frontend and retry
     2) Proceed without starting frontend
     3) Skip check and attempt to start anyway
   
   Select option [1-3]: 
   ```

### Option 1: Stop frontend and retry
- If the frontend was started by this Makefile, it will automatically stop it
- Otherwise, prompts you to manually terminate the service
- The port check will run again after stopping

### Option 2: Proceed without frontend
- Creates a `.frontend.skip` file
- Backend services start normally
- Frontend startup is skipped
- Status commands will show frontend as "Skipped"

### Option 3: Skip check and attempt to start anyway
- Ignores the port check and tries to start frontend anyway
- Useful if you know the port will be free by the time frontend starts
- May result in frontend startup failure if port is still in use

## Status Display

When frontend is skipped:
```
Services running at:
  Frontend:    ⚠️  Skipped (port 8100 was in use)
  Backend API: http://localhost:8101
  API Docs:    http://localhost:8101/docs
  ChromaDB:    http://localhost:8102
```

## Manual Frontend Start

If you chose to skip the frontend, you can start it manually later:
```bash
cd frontend/synapse && npm run dev
```

## Cleanup

The `.frontend.skip` file is automatically removed when you run:
- `make stop`
- `make clean`
- Or when port 8100 becomes available on the next `make dev`

This approach ensures that backend services can always start, even if another process is using the frontend port.