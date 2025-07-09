# Synapse: Your Knowledge, Captured.

<div align="center">
  <img src="frontend/synapse/public/synapse-logo-2.png" alt="Capture Logo" width="400" />
  
 *Your brain is full. Let's fix that.*
</div>

## What is this Glorious Contraption?

Is your browser buried under 1,000 tabs of "I'll read this later"? Is your notes app a digital graveyard of forgotten brilliance? Do you have more markdown files than memories?

Good. You're in the right place.

**Synapse** is a local-first, AI-powered knowledge management system that *actually* remembers stuff for you. Feed it articles, meeting notes, code snippets, and your half-baked shower thoughts. Then, ask it questions in plain English. It doesn't just search—it understands, synthesizes, and gives you intelligent answers, complete with citations from... well, from *you*.

It's the ultimate "I told you so" machine, and you're telling yourself.

## The "Magic" (It's Not Magic, It's RAG)

1.  **You Feed the Beast:** Drop in any text document.
2.  **It Chews on It:** Synapse uses advanced models to chunk and create vector embeddings (think of them as "idea-fingerprints").
3.  **You Ask a Question:** "What were the security concerns from that one frontend report?"
4.  **It Thinks:** It finds the most relevant "idea-fingerprints," reads the original text, and uses a powerful local LLM to generate a human-like answer.
5.  **You Look Like a Genius:** You get a perfect summary, complete with links to the exact sources you fed it.

All of this happens **on your machine**. No cloud provider is reading your plans for world domination.

## The Bragging Rights (The Stack)

This isn't your weekend Flask project. This is a fully containerized, asynchronous, multi-database system built with a modern, ridiculously fast stack because waiting is for Luddites.

  * **🧠 Brains:** `Ollama` running your favorite local LLMs (currently `gemma3n:e4b`). Because who needs the cloud when you have a perfectly good space heater... I mean, GPU.
  * **🚀 Engine:** `FastAPI` + `Haystack 2.0` doing the heavy lifting. Asynchronous, performant, and probably over-engineered for a personal project. We love it.
  * **🎭 Face:** `Next.js 15` with dark mode that's easier on the eyes than your IDE's "Dracula" theme.
  * **🗄️ Memory:** `SQLite` for the facts, `ChromaDB` for the vibes (and vectors).
  * **🔒 Security:** XSS protection with DOMPurify because we don't trust AI responses (or you).

Forged in the fires of late-night coding sessions and way too many build reports, this thing is hardened and ready.

## You Know You Want To (Quick Start)

This thing is a starter kit you can build damn near anything on. Feeling brave?

### Prerequisites

  * **Python 3.11+** (for the backend wizardry)
  * **Node.js 18+** (for the frontend sparkle)
  * **Docker & Docker Compose** (for container orchestration)
  * **[Ollama](https://ollama.ai/)** (optional but recommended for local LLMs)
  * **curl** (you probably have this)

### 🚀 The One-Command Wonder

```bash
git clone https://github.com/josephrclick/synapse.git
cd synapse
make init        # First time? Start here!
make run-all     # Start everything (Docker + frontend)
```

That's it. Seriously. The Makefile handles everything:
- ✅ Creates `.env` files with sensible defaults
- ✅ Installs all dependencies (Python & Node.js)
- ✅ Builds and starts Docker containers with health checks
- ✅ Waits for services to be ready before proceeding
- ✅ Launches the frontend in the background

### 🎯 Common Commands

```bash
make run-all     # Start all services (recommended)
make check-ports # Verify ports are available
make logs        # View Docker logs
make stop-all    # Stop all Docker services
make help        # Show all available commands
```

### 🔐 Testing & Quality

```bash
# Backend testing
cd backend && ./run_tests.sh  # Run test suite
```

Wait for the Docker containers to spin up and the matrix to load. Pro tip: If you see ASCII art, you're doing it right.

### Access Points

  * **The Pretty Part (UI):** `http://localhost:8100`
  * **The Engine Room (API):** `http://localhost:8101`
  * **The Blueprints (API Docs):** `http://localhost:8101/docs`

## The Fine Print

### Configuration

Everything important is in the root `.env` file. The Makefile will create one for you with sensible defaults. Want to get fancy? Check out `.env.production.example` for hardened settings.

### 🧪 Development Commands

```bash
# Frontend commands
cd frontend/synapse
npm run dev      # Development server
npm run build    # Production build
npm run lint     # Run ESLint

# Backend commands
cd backend
./setup_and_run.sh  # Full setup and run
pip install -r requirements.txt  # Install deps in venv
```

### 🔧 Configuration

Port configuration is centralized in the root `.env` file:

```bash
# Application Ports (Host-side)
FRONTEND_PORT=8100
API_PORT=8101
CHROMA_GATEWAY_PORT=8102
```

### 🚨 Production Settings

When deploying to production, ensure these critical settings:

```bash
# In docker-compose.yml or production .env
CHROMADB_ALLOW_RESET=FALSE  # CRITICAL: Prevents accidental data loss
```

**Important:** The default development setting allows database resets. Always set `CHROMADB_ALLOW_RESET=FALSE` in production environments to protect your data.

### The Roadmap

  * [x] ~~Make it work~~ ✅
  * [x] ~~Make it fast~~ ✅  
  * [x] ~~Make it pretty~~ ✅
  * [ ] Add voice input (Deepgram PoC already in!)
  * [ ] Make it predict what you're thinking
  * [ ] Achieve sentience (but like, the friendly kind)

### Known "Features"

  * The AI sometimes gets philosophical. We consider this a feature.
  * ChromaDB might use more RAM than Chrome. Isn't it ironic? Don't ya think?
  * If you feed it your diary, it might become too emotionally intelligent.

-----

<div align="center">

**Synapse** - Because your brain deserves a backup.

*Built with ☕ and too many late nights*

</div> 
