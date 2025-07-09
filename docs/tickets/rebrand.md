Of course. Here is a comprehensive ticket to hand off to your developer for the "synapse" to "synapse" refactoring.

***

# Build Ticket: Project Rebrand - Refactor 'synapse' to 'synapse'

**Project:** Synapse
**Ticket ID:** `SYN-101`
**Priority:** High
**Assignee:** [Developer Name]

## 1. Objective

This ticket outlines the full-scale refactoring of the project from its codename "synapse" to its official name, "synapse". Now that we have a working MVP, we need to update all project assets, code, and documentation to reflect the new branding for a clean, consistent, and professional codebase.

## 2. Scope of Work

The refactoring will touch nearly every part of the repository. The changes can be broken down into the following categories:

### A. Directory and File Renaming

-   Rename the primary frontend directory:
    -   **From:** `frontend/synapse`
    -   **To:** `frontend/synapse`
-   Rename the primary SQLite database file (and ensure all configurations point to the new name):
    -   **From:** `synapse.db`
    -   **To:** `synapse.db`

### B. Code and Configuration Updates

-   **`docker-compose.yml`**:
    -   Update the `build.context` for the `backend` service if it's affected by path changes.
    -   Consider renaming the service itself from `backend` to `synapse-api` for clarity, though this is optional.
-   **`package.json` files**:
    -   In `frontend/synapse/package.json`, change `"name": "synapse"` to `"name": "synapse-frontend"`.
    -   In `backend/package.json`, change `"name": "backend"` to `"name": "synapse-backend"`.
-   **Backend Code (`/backend`)**:
    -   In `config.py`, update `app_name` from "Synapse Engine" to "Synapse Engine".
    -   In `config.py`, change the default `sqlite_db_path` from "./synapse.db" to "./synapse.db".
    -   In `main.py`, update the `title` in the FastAPI app instantiation from "Synapse Engine" to "Synapse".
    -   Perform a global search for "synapse" and "Synapse" within the `/backend` directory and replace with "synapse" and "Synapse" respectively in all comments, log messages, and strings.
-   **Frontend Code (`/frontend/synapse`)**:
    -   In `app/layout.tsx`, update the metadata `title` and `description` to remove "Synapse" and use "Synapse".
    -   In `app/components/Navigation.tsx`, update any hardcoded "Synapse" text to "Synapse".
    -   Perform a global search for "synapse" and "Synapse" within the `/frontend/synapse` directory and replace where appropriate.

### C. Scripts and Automation

-   **`Makefile`**:
    -   Update all paths that reference `frontend/synapse`.
    -   Review all commands and descriptions for mentions of "synapse".
-   **All Shell Scripts (`.sh`)**:
    -   Review `run_tests.sh`, `setup_and_run.sh`, etc., for any hardcoded paths or references.

### D. Documentation

-   Update `README.md` (root) to reflect the "Synapse" branding, removing all mentions of "synapse".
-   Update `CLAUDE.md` to reflect new file paths and project names.
-   Search all files in the `/docs` directory for "synapse" and replace with "Synapse".

## 3. Implementation Plan

A phased approach is recommended to manage the scope and risk of this refactor. **Commit your changes after each successful phase.**

1.  **Phase 1: Preparation**
    -   Ensure you are working on a new feature branch.
    -   Make sure the current `main` branch is stable and all tests are passing.

2.  **Phase 2: Backend Refactor**
    -   Start with the backend code and configuration files. Change all internal strings, comments, and configuration values (e.g., `app_name`, `sqlite_db_path`).
    -   Run backend tests (`make test`) to ensure nothing has broken.

3.  **Phase 3: Filesystem & Path Refactor**
    -   Rename the `frontend/synapse` directory to `frontend/synapse`.
    -   Update all files that reference this path. This will include the `Makefile`, `docker-compose.yml`, and any scripts.
    -   Rename the database file `synapse.db` to `synapse.db` (note: this will reset the database unless you manually migrate the data).

4.  **Phase 4: Frontend & Documentation Refactor**
    -   Update the `package.json` name for the frontend.
    -   Update all user-facing text, titles, and metadata in the frontend components.
    -   Update all documentation files (`.md`) to reflect the new name.

5.  **Phase 5: Verification & Cleanup**
    -   Delete any old build caches (e.g., `/.next`, `__pycache__`).
    -   Run `make clean` if available.
    -   Rebuild the entire project from scratch using `make rebuild-all` or a similar clean build command.
    -   Run all tests and manually verify the application.

## 4. Acceptance Criteria

-   [ ] A global search for the string "synapse" (case-insensitive) in the repository yields zero results (outside of git history).
-   [ ] The project builds and runs successfully using `make run-all`.
-   [ ] All backend tests pass (`make test`).
-   [ ] The frontend UI correctly displays "Synapse" as the project name with no mention of "synapse".
-   [ ] The API documentation at `/docs` shows the new application title.
-   [ ] The application creates a `synapse.db` file, not `synapse.db`.

## 5. Risks & Considerations

-   **Broken Paths:** This is the highest risk. A global find-and-replace is powerful but must be used with care. Verify all path changes in configuration and script files.
-   **Build Caches:** Stale caches (Docker, Next.js, Python) may cause issues. A clean rebuild is essential after the refactor.
-   **Database:** The default plan will result in a new, empty database. If existing data must be preserved, a migration step (renaming the old `.db` file) will be needed. For the MVP, starting fresh is acceptable.
-   **Git History:** Renaming directories can sometimes confuse git history viewers. This is an accepted consequence of the rebrand.

## 6. Recommended Tools

-   **IDE Refactoring:** Use your IDE's "Refactor -> Rename" functionality where possible, as it can intelligently update imports.
-   **Global Search & Replace:** Use a tool like `grep` and `sed`, or your IDE's global search, to find and replace all instances of "synapse" and "Synapse".