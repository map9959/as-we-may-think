# As We May Think

An implementation of Vannevar Bush's Memex. Simple optional scrolling RSS feed reader (no CSS or real parsing!), note taking and retrieval, and a local LLM assistant that can answer questions based on your notes.

## Structure
The frontend is located in `lib`, the backend is located in `backend`. Place LLM GGUFs in `backend/models`. Backend is a FastAPI project running SQLite as a local database, frontend is Flutter. Descriptions of architecture and features are located in `descriptions`.

## Getting Started

### Prerequisites
- Python 3.10+
- Flutter SDK (latest stable)

### 1. Run the Backend

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment with [uv](https://github.com/astral-sh/uv):
   ```bash
   uv venv
   source .venv/bin/activate
   ```
3. Install dependencies and sync environment:
   ```bash
   uv sync
   ```
4. Start the backend server:
   ```bash
   uv run uvicorn main:app --reload
   ```
   The backend will run on `http://localhost:8000` by default.

### 2. Run the Frontend

1. Return to the project root:
   ```bash
   cd ..
   ```
2. Get Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the app (choose your platform):
   - **Mobile (Android/iOS):**
     ```bash
     flutter run
     ```
   - **Web:**
     ```bash
     flutter run -d chrome
     ```
   - **Desktop (Linux/Mac/Windows):**
     ```bash
     flutter run -d linux
     # or -d macos / -d windows
     ```

## Vibe Coding

What's more interesting than the software itself is its development process. I pick a feature from the handwritten "roadmap" in `descriptions/main.md` and specify its functional requirements to an LLM. To meet non-functional requirements, I specify certain implementation details (such as names of API endpoints and their functions) and pitfalls to avoid. I ask the LLM to write a detailed document for the implementation, and I review it. The LLM writes a first draft of these functions and their tests, fully covering the desired behavior. I then iterate through a test-driven development loop until the tests pass, and finally manually QA myself.