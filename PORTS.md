# Port Allocation for Synapse

## Port Range: 8100-8199

This project uses ports in the 8100-8199 range to avoid conflicts with common development tools.

### Current Allocations

| Service | Host Port | Container Port | Description |
|---------|-----------|----------------|-------------|
| Frontend (Next.js) | 8100 | 3000 | Web UI development server |
| Backend API (FastAPI) | 8101 | 8000 | REST API server |
| ChromaDB | 8102 | 8000 | Vector database |
| Reserved | 8103-8109 | - | Future HTTP services |
| Reserved | 8110-8119 | - | Debug/admin interfaces |
| Reserved | 8120-8199 | - | Auxiliary services |

### Common Port Conflicts to Avoid

- **3000**: Often used by Node.js apps, Grafana
- **8000**: Python dev servers, Portainer
- **8080**: Default for many web services, Jenkins
- **5432**: PostgreSQL
- **6379**: Redis
- **9000**: PHP-FPM, Portainer

### Environment Configuration

All ports are configured in the root `.env` file:

```bash
FRONTEND_PORT=8100
API_PORT=8101
CHROMA_GATEWAY_PORT=8102
```

### Development vs Production

- **Development**: Uses the 8100 range as documented above
- **Production**: Should use standard ports (80/443) behind a reverse proxy
- Use `.env.production` to override for production deployments

### Checking Port Availability

Before starting services:
```bash
# Check if ports are free
lsof -i :8100-8102

# Or use the Makefile
make check-ports
```

### Quick Start

```bash
# Start all services with configured ports
make run-all

# View current port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"
```