### **Project Charter & Master Build Plan: Capture-v3**

Document Version: 4.0 (Final Build Plan)

### **1\. Overview & Philosophy**

#### **1.1. Intent**

**Capture-v3** is a private, "second brain" for professional and personal development. Its purpose is to ingest, connect, and retrieve a diverse range of data—from job descriptions and meeting notes to technical articles and dictated thoughts. It transforms this chaotic stream of information into a structured, searchable, and insightful personal knowledge graph.

#### **1.2. Core Philosophy**

* **Pragmatic Local:** The system's core services run locally for privacy, speed, and cost-efficiency. However, it is designed from the ground up to be a hybrid system, pragmatically connecting to external cloud and internet services (e.g., Deepgram, frontier LLM APIs) wherever they provide superior value.  
* **Intelligent & Extensible:** The system is built around a modern RAG (Retrieval-Augmented Generation) pipeline. The architecture is modular, designed to easily incorporate new technologies in the future.  
* **Dead Simple, Highly Effective:** We prioritize simplicity, reliability, and speed of implementation. Every component is chosen for its ability to deliver maximum value with minimum complexity.

### **2\. Core Mandates: How We Build**

This project is governed by a set of core mandates that prioritize momentum and quality.

* **MVP is Law:** The North Star for all initial development is to ship a working Minimum Viable Product. We will aggressively cut scope to achieve a functional, end-to-end system as quickly as possible.  
* **Ship Fast, Then Iterate:** We build the simplest possible version of a feature that delivers value, ship it, and then gather real-world feedback to guide the next iteration.  
* **Measure Twice, Cut Once:** We do our homework. We check our assumptions and validate our tech choices *before* we write the code. Diligence upfront prevents wasted cycles later.  
* **Check Your Work:** Every completed task must be verified against its acceptance criteria. We are responsible for ensuring our work is complete, functional, and well-documented before moving on.

### **3\. System Architecture & Data Flow**

The system follows a decoupled architecture, orchestrated locally via Docker Compose.

1. **The Face (Frontend):** A **Next.js** application providing the user interface.  
2. **The Engine (Backend):** A **Python/FastAPI** service containing all RAG logic and the data model.  
3. **The Brain (LLM Serving):** An **Ollama** instance serving local models.  
4. **The Memory (Datastores):** A robust, two-database model for persistence.  
   * **SQLite:** The primary datastore for master records and metadata.  
   * **ChromaDB:** The secondary, specialized datastore for vector embeddings only.

#### **Data Flow for Ingestion:**

1. A document (text, audio transcript) is sent to **The Engine**.  
2. **The Engine** saves the full document text and its metadata to a new record in the **SQLite** database with a status of 'pending', generating a unique ID.  
3. **The Engine** then runs its Haystack pipeline: it chunks the document text, sends the chunks to **The Brain (Ollama)** for embedding, and writes the resulting chunks and their vectors to **ChromaDB**, with each chunk's metadata referencing the master record's ID from SQLite.  
4. Upon successful embedding, the document's status in SQLite is updated to 'completed'. If an error occurs, the status is set to 'failed' and the error message is logged.

### **4\. Data Model & Schema (MVP)**

#### **4.1. SQLite Database (backend/capture.db)**

The SQLite database will contain our master records.

* **documents table:** The central table for all ingested content.  
  * id (TEXT, PRIMARY KEY) \- A UUID for the document.  
  * type (TEXT) \- The type of document (e.g., "job\_post", "interview\_note", "general\_note").  
  * title (TEXT) \- A human-readable title.  
  * content (TEXT) \- The full, original text content.  
  * source\_url (TEXT, NULLABLE) \- The original URL, if applicable.  
  * status (TEXT, NOT NULL, DEFAULT 'pending') \- The processing status ('pending', 'processing', 'completed', 'failed').  
  * processing\_error (TEXT, NULLABLE) \- Stores error messages if ingestion fails.  
  * created\_at (TEXT) \- ISO 8601 timestamp.  
* **document\_links table:** A junction table to create many-to-many relationships.  
  * source\_doc\_id (TEXT, FOREIGN KEY to documents.id)  
  * target\_doc\_id (TEXT, FOREIGN KEY to documents.id)  
  * PRIMARY KEY (source\_doc\_id, target\_doc\_id)

#### **4.2. ChromaDB Collection (knowledge\_base)**

A single ChromaDB collection will store all vector embeddings.

* **Chunk Metadata Schema:**  
  * doc\_id (string): The UUID of the master document from the SQLite documents table.  
  * doc\_type (string): The type from the master document (e.g., "job\_post").  
  * doc\_title (string): The title from the master document.

### **5\. Technical Specifications**

| Category | Technology / Library | Version / Specification | Notes |
| :---- | :---- | :---- | :---- |
| **Backend** | Python | 3.11 (LTS) | Ensures stability and compatibility. |
|  | FastAPI | Latest Stable | For building the API. |
|  | Haystack | 2.x (haystack-ai) | The core RAG orchestration library. |
|  | SQLite | v3 | Managed via Python's built-in sqlite3 module. |
|  | ChromaDB Client | chromadb-client | To communicate with the ChromaDB container. |
| **LLM Serving** | Ollama | Host OS Install | For local model access. |
| **Vector DB** | ChromaDB | Containerized | For vector storage. |
| **Frontend** | Next.js | 15 (LTS) | For the user interface. |
| **Models** | Generative | gemma3n:e2b (Initial) | All models managed via .env file. |
|  | Embedding | mxbai-embed-large |  |
|  | Reranker | bge-reranker-v2-m3 |  |
| **Services** | Speech-to-Text | Deepgram | deepgram-sdk |

#### **5.1. RAG Pipeline Configuration**

* **Chunking Strategy:** Haystack DocumentSplitter will be configured with split\_by="sentence", split\_length=10, and split\_overlap=2.

### **6\. API Contract & Security (MVP)**

#### **6.1. API Endpoints**

* POST /api/documents: A single, flexible endpoint for all document ingestion.  
* GET /api/documents: To list all master documents.  
* GET /api/documents/{doc\_id}: To retrieve a specific master document.  
* POST /api/chat: To query the knowledge base.  
* GET /health: A health check endpoint to verify service status.

#### **6.2. Ingestion Contract**

Endpoint: POST /api/documents  
Request Body:  
{  
  "type": "interview\_note",  
  "title": "Follow-up call with hiring manager",  
  "content": "The conversation went well. We discussed the technical challenges of the role...",  
  "source\_url": null,  
  "tags": \["interview", "follow-up"\s],  
  "link\_to\_doc\_id": "uuid-of-the-job-post-document"  
}

#### **6.3. Security**

All API endpoints must be protected by a shared secret API key. The key will be passed in the X-API-KEY header and validated by a FastAPI dependency.

### **7\. Phased Build Plan Summary**

* **Phase 1: Core Infrastructure & Backend API (Current Focus)**  
  * **Goal:** Establish a fully functional, containerized backend with a robust two-database storage system, basic authentication, and working RAG pipelines that can be tested via an API client.  
* **Phase 2: Frontend Integration**  
  * **Goal:** Connect a simple web interface to the backend API, allowing for document ingestion, management, and chat.  
* **Phase 3: Voice Integration**  
  * **Goal:** Enable hands-free data capture by integrating speech-to-text functionality.

### **8\. Scope & Limitations (MVP)**

* **IN SCOPE:**  
  * A robust two-database persistence model (SQLite \+ ChromaDB).  
  * Transactional ingestion with status tracking.  
  * A flexible ingestion endpoint supporting document linking.  
  * A high-quality RAG query pipeline with reranking.  
  * Basic, structured logging for debugging.  
  * All model names and API keys managed via environment variables.  
  * Basic API key authentication and a service health check endpoint.  
* **OUT OF SCOPE:**  
  * Advanced security features (e.g., JWT, OAuth).  
  * Automated performance monitoring or benchmarking tools.  
  * Complex agentic workflows.