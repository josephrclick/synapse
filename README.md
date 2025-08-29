⚠️ **Work in Progress (Pre-Alpha)**

This extension is under active development. It’s not production-ready and APIs/UI may change without notice.
If you’re exploring the code, great! If you’re expecting a stable tool, please wait for v1.0.

---

# Synapse: Your Knowledge, Captured.

<div align="center">
  <img src="frontend/synapse/public/synapse-logo-2.png" alt="Capture Logo" width="400" />
  
 *Your brain is full. Let's fix that.*
</div>

## Ever forget something?

Is your notes app a digital graveyard of forgotten brilliance?

Is your browser buried under 400 tabs of "Revisit this later" or do you bury those deeper into bookmark oblivion?  

Do you have more markdown files than memories?

You're in the right place, and you're not alone.

**Synapse** is a local-first, AI-powered knowledge management system that *actually* remembers stuff for you. Feed it articles, meeting notes, emails, voice notes, half-baked shower thoughts. Then, ask it questions. It doesn't just search - it understands, synthesizes, makes connections, and gives you intelligent answers, complete with citations from... well, from *you*.

It's the ultimate "I told you so" machine, and you're telling yourself.

## The "Magic" (It's Not Magic, It's RAG)

1.  **You Feed the Beast:** Drop in any text document. Soon to support other file types, voice transcripts, etc.
2.  **It Chews on It:** Synapse uses advanced models to chunk and create vector embeddings (think of them as "idea-fingerprints").
3.  **You Ask a Question:** "What was I supposed to prep for my meeting with Bob next week?" or "Summarize everything we know about Bob I may need for our meeting. Do a deep dive and report any insights to help me crush this thing, please?" 
4.  **It Thinks:** It finds the most relevant idea-fingerprints across all the disparate stuff you've ever fed in over time, uses a local LLM of your choice to do it's AI thing, and possibly generates amazing connections and insights you would have never surfaced yourself.
5.  **You Look Like a Genius:** You get the output valuable to you, grounded in your data, complete with links to the exact sources you fed it. Imagine the possibilities.

All of this happens **on your machine** if you wish. No cloud provider reading your plans for world domination.

## The Stack - for now

This isn't your weekend Flask project. This is a fully containerized, asynchronous, multi-database system built with a modern, ridiculously fast stack because waiting is for Luddites.

  * **🧠 Brains:** `Ollama` running your favorite local LLMs. Because who needs the cloud when you have a perfectly good space heater... I mean, GPU.
  * **🚀 Engine:** `FastAPI` + `Haystack 2.0` doing the heavy lifting. Asynchronous, performant, and probably over-engineered for a personal project. We love it.
  * **🎭 Face:** `Next.js 15` with dark mode that's easier on the eyes than your IDE's "Dracula" theme.
  * **🗄️ Memory:** `SQLite` for the facts, `ChromaDB` for the vibes (and vectors).
  * **🔒 Security:** XSS protection with DOMPurify because we don't trust AI responses (or you).
  * **📦 Containers:** Everything runs in Docker now - Ollama, ChromaDB, and the backend API. One command to rule them all.

Forged in the fires of late-night coding sessions and way too many build reports, this thing is hardened and ready.

## You Know You Want To (Quick Start)

This thing is a starter kit you can build damn near anything on. Feeling brave?

### Prerequisites

  * **Python 3.11+** (for local development)
  * **Node.js 18+** (for the frontend)
  * **Docker & Docker Compose** (required - everything runs in containers)
  * **Make** (for automation commands)

### 🚀 The One-Command Wonder

```bash
git clone https://github.com/josephrclick/synapse.git
cd synapse
make init        # First time? Start here!
make dev         # Start everything with interactive setup
```

That's it. Seriously. The Makefile handles everything:
- ✅ Creates `.env` files with sensible defaults
- ✅ Installs all dependencies (Python & Node.js)
- ✅ Builds and starts Docker containers with proper health checks
- ✅ **Interactive port handling** - if port 8100 is busy, choose to retry or skip frontend
- ✅ **Interactive model management** - download only the models you need, when you need them
- ✅ Waits for all services to be healthy using Docker's native health status
- ✅ Automatically manages service dependencies (backend waits for healthy ChromaDB/Ollama)

### 🎯 Common Commands

```bash
make dev         # Start all services with interactive setup
make stop        # Stop all services
make status      # Show service status and health
make health-detailed # Show Docker health status for each service
make logs        # View logs from all services

# Model Management
make check-models    # See which Ollama models are installed
make interactive-pull-models # Interactive model selection menu
make pull-models     # Pull all required models at once

# Debugging
make logs-backend    # View backend logs only
make logs-ollama     # View Ollama logs
make troubleshoot    # Interactive troubleshooting guide
make help           # Show all available commands
```

### 🧪 Testing

```bash
./tests/test-all.sh   # Run all tests (API, frontend, Ollama)
```

See [tests/TESTING.md](tests/TESTING.md) for complete testing documentation.


### Access Points

  * **The Pretty Part (UI):** `http://localhost:8100`
  * **The Engine Room (API):** `http://localhost:8101`
  * **The Blueprints (API Docs):** `http://localhost:8101/docs`

## The Fine Print

### 🔧 Configuration

Everything important is in the root `.env` file. The Makefile will create one for you with sensible defaults. For production settings, see `.env.production.example`.

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

### 🚑 Quick Troubleshooting

```bash
# Check if everything is running with Docker health status
make health-detailed

# View logs if something's wrong
make logs-backend   # Backend issues
make logs-ollama    # Model download status
make logs-chromadb  # Vector DB issues

# Interactive troubleshooting guide
make troubleshoot

# Nuclear option - reset everything
make reset && make init && make dev
```

### The Roadmap

  * [x] ~~Make it work~~ ✅
  * [x] ~~Make it fast~~ ✅  
  * [x] ~~Make it pretty~~ ✅
  * [x] ~~Interactive model management~~ ✅
  * [x] ~~Smart port handling~~ ✅
  * [ ] Add voice input (Deepgram PoC already in!)
  * [ ] Make it predict what you're thinking
  * [ ] Achieve sentience (but like, the friendly kind)

### Known "Features"

  * The AI sometimes gets philosophical. We consider this a feature.
  * ChromaDB might use more RAM than Chrome. Isn't it ironic? Don't you think?
  * If you feed it your diary, it might become too emotionally intelligent.
  * First run is now interactive - choose which models to download (3-5GB each)
  * Frontend port conflicts? No problem - the system asks what you want to do

-----

<div align="center">

**Synapse** - Because your brain deserves a backup.

*Built with ☕ and too many late nights*

</div> 
