# Technical Stack & Development Guidelines

## Tech Stack

### Frontend
- **Framework**: Flutter (SDK ^3.6.0)
- **State Management**: Provider (^6.1.2)
- **HTTP Client**: http (^1.3.0)
- **Dependencies**:
  - english_words (^4.0.0)
  - file_picker (^6.1.1)
  - path (^1.9.0)

### Backend
- **Framework**: FastAPI
- **Database**: SQLite with async support (aiosqlite)
- **ORM**: SQLModel
- **LLM Integration**:
  - llama-cpp-python
  - transformers
  - sentence-transformers
  - faiss-cpu (for vector embeddings)
- **Additional Libraries**:
  - feedparser (RSS parsing)
  - httpx (async HTTP client)
  - python-dateutil
  - pytest & pytest-asyncio (testing)

## Build & Run Commands

### Backend Setup
```bash
cd backend
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
uv sync
uv run uvicorn main:app --reload
```

### Frontend Setup
```bash
flutter pub get
flutter run              # For mobile
flutter run -d chrome    # For web
flutter run -d linux     # For Linux (or -d macos / -d windows)
```

## LLM Models
- Place GGUF model files in `backend/models/` directory
- Recommended models:
  - Llama 3 8B
  - Phi-3 Mini
  - TinyLlama

## Development Guidelines

### API Conventions
- RESTful endpoints with consistent naming
- Use HTTP status codes appropriately (201 for creation, 204 for deletion)
- JSON for request/response bodies

### Database
- Use SQLModel for all database models
- Async database operations with proper session management
- UUID primary keys for notes and related entities

### Testing
- Backend tests with pytest in `backend/test_main.py`
- Frontend widget tests in `test/widget_test.dart`

### Code Style
- Follow Flutter/Dart style guidelines for frontend
- Follow PEP 8 for Python backend code
- Use type hints in Python code