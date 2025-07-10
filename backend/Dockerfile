# syntax=docker/dockerfile:1

# Stage 1: Builder - compile wheels and prepare dependencies
FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    make \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy dependency files
COPY requirements.txt requirements.in ./

# Upgrade pip and build wheels
RUN pip install --upgrade pip wheel && \
    pip wheel --wheel-dir=/wheels -r requirements.txt

# Stage 2: Runtime - minimal image with just app and runtime deps
FROM python:3.11-slim

# Install runtime dependencies (if any are needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 appuser

# Set working directory
WORKDIR /app

# Copy wheels from builder and install
COPY --from=builder /wheels /wheels
COPY requirements.txt ./
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt && \
    rm -rf /wheels

# Pre-compile Python bytecode for faster startup
RUN python -m compileall -q /usr/local/lib/python3.11/site-packages

# Create backend module directory
RUN mkdir -p backend

# Copy only the backend application code
COPY --chown=appuser:appuser *.py ./
COPY --chown=appuser:appuser setup_and_run.sh ./

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV API_CONTAINER_PORT=8000

# Expose the default port
EXPOSE 8000

# Switch to non-root user
USER appuser

# Run the FastAPI application with uvicorn
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${API_CONTAINER_PORT:-8000} --reload"]