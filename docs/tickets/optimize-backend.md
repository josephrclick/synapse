### **Build Ticket: Optimize Backend Dependencies**

**Project:** Synapse **Ticket ID:** `SYN-102` **Priority:** **Critical** **Assignee:** \[Developer Name\]

### 1\. Objective

To dramatically reduce the backend application's size and improve build performance by removing unnecessary dependencies, resolving version conflicts, and updating core packages without impacting existing functionality. This addresses a major bloat issue where ~2GB of unused ML libraries are being installed.

### 2\. Background & Problem Statement

An audit of the backend dependencies has revealed several critical issues:

1.  **Massive Dependency Bloat:** The primary issue is that `sentence-transformers` is included in `requirements.in`. This package transitively installs the entire PyTorch and CUDA ecosystem (~2GB), which is completely unnecessary as our RAG pipeline exclusively uses Ollama for embeddings (`OllamaDocumentEmbedder` and `OllamaTextEmbedder`).
    
2.  **Unused Direct Dependencies:** Several packages are listed in `requirements.in` but are never imported or used in the application code. These include `deepgram-sdk`, `nltk`, and `accelerate`.
    
3.  **Build-Breaking Version Conflict:** The locked `requirements.txt` specifies `haystack-ai==2.15.2`, which is not a valid version available on PyPI. This prevents reproducible builds for new developers.
    
4.  **Outdated Core Packages:** Key libraries like `pydantic` and `fastapi` are pinned to older versions, preventing us from benefiting from recent performance and security updates.
    

### 3\. Phased Implementation Plan

This plan is designed to be executed sequentially to ensure stability at each step.

#### **Phase 1: Clean Up `requirements.in`**

1.  **Edit `backend/requirements.in`:** Open this file and remove the following lines, as they are unused or the source of the bloat:
    
    -   `sentence-transformers>=2.2.2`
        
    -   `deepgram-sdk==3.1.6`
        
    -   `nltk>=3.9.1`
        
    -   `accelerate>=1.8.0`
        
2.  **Edit `backend/requirements.in` (Again):** Correct the `haystack-ai` version constraint. The locked version `2.15.2` is invalid. Update the line to allow for the latest compatible `2.x` version.
    
    -   **Change From:** `haystack-ai>=2.15,<2.16`
        
    -   **Change To:** `haystack-ai>=2.0,<3.0`
        

#### **Phase 2: Regenerate and Verify Locked Dependencies**

1.  **Activate Virtual Environment:** Ensure you are in the project's Python virtual environment. `backend/venv/bin/activate`
    
2.  **Run `pip-compile`:** Execute the following command from the repository root to regenerate the `requirements.txt` file. The `--upgrade` flag will remove the old packages and update the remaining ones to their latest compatible versions.
    
    Bash
    
    ```
    pip-compile --upgrade backend/requirements.in -o backend/requirements.txt
    
    ```
    
3.  **Verify the Output:** Open the newly generated `backend/requirements.txt`. Confirm that `torch`, `sentence-transformers`, `nltk`, `deepgram-sdk`, `accelerate`, and all `nvidia-*` packages are **GONE**. You should also see updated versions for packages like `pydantic` and `fastapi`.
    

#### **Phase 3: Test and Validate**

1.  **Rebuild Docker Image:** It is critical to rebuild the backend Docker image without using the cache to ensure the new, smaller dependency set is used.
    
    Bash
    
    ```
    docker compose build --no-cache backend
    
    ```
    
2.  **Run Full Test Suite:** Start the services (`make run-all` or `docker compose up -d`) and execute the full backend test suite to confirm that no functionality has been broken.
    
    Bash
    
    ```
    ./backend/run_tests.sh
    
    ```
    
3.  **Manual End-to-End Test:**
    
    -   Ingest a new document via the frontend.
        
    -   Verify it processes successfully by checking its status.
        
    -   Use the chat interface to ask a question related to the new document. Confirm you receive a valid answer and sources.
        

### 4\. Acceptance Criteria

-   \[ \] The packages `sentence-transformers`, `deepgram-sdk`, `nltk`, and `accelerate` are removed from `backend/requirements.in`.
    
-   \[ \] The regenerated `backend/requirements.txt` file does **not** contain `torch` or any `nvidia-*` packages.
    
-   \[ \] The `haystack-ai` version is a valid, installable version from PyPI.
    
-   \[ \] The backend Docker image builds successfully and is significantly smaller in size (target < 1GB).
    
-   \[ \] All backend tests pass successfully after the changes.
    
-   \[ \] The application is fully functional: document ingestion and RAG chat work as expected.
    

### 5\. Expected Benefits

-   **Massive Reduction in Size:** 70-80% reduction in Docker image size.
    
-   **Faster Builds:** CI/CD and local setup times will be dramatically faster.
    
-   **Reduced Attack Surface:** Fewer packages mean fewer potential security vulnerabilities.
    
-   **Architectural Clarity:** The dependency list will now accurately reflect that Ollama is the sole ML provider in the stack.