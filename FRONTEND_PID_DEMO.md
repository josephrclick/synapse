# Frontend PID Management Demo

The Makefile now shows the frontend process ID (PID) when starting and stopping the frontend.

## Starting Frontend

When you run `make dev` or `make start-frontend-background`, you'll see:

```
Starting frontend...
✅ Frontend started (PID: 12345)
   URL: http://localhost:8100
```

## Checking Status

Running `make status` shows:

- If started by Makefile:
  ```
  Frontend:
    ✅ Running (Makefile-managed, PID: 12345)
    URL: http://localhost:8100
  ```

- If started externally:
  ```
  Frontend:
    ✅ Running (externally managed)
    URL: http://localhost:8100
  ```

## Stopping Services

When you run `make stop`:

```
Stopping all services...

Stopping Docker services...
[Docker compose output]

Stopping frontend...
Stopping frontend (PID: 12345)...
✅ Frontend stopped

✅ All services stopped
```

## Features

1. **PID Display**: Shows the process ID when starting the frontend
2. **Graceful Shutdown**: First sends SIGTERM, waits 2 seconds, then SIGKILL if needed
3. **Status Detection**: Differentiates between Makefile-managed and externally-managed frontends
4. **Clean Stop**: The `make stop` command now properly stops both Docker services and the frontend

## Error Handling

- If the PID file exists but the process is already dead, it shows:
  ```
  Frontend PID 12345 not found (already stopped)
  ```

- If no PID file exists when stopping:
  ```
  No frontend PID file found
  ```

This ensures clean process management and clear feedback about what's happening with the frontend service.