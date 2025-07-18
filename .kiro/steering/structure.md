# Project Structure

## Overview
The project follows a clear separation between frontend (Flutter) and backend (Python/FastAPI) components.

## Directory Organization

### Root Level
- `/lib` - Flutter frontend code
- `/backend` - Python FastAPI backend
- `/descriptions` - Architecture and feature documentation
- `/test` - Flutter tests

### Frontend Structure (`/lib`)
- `/lib/api` - API service for communicating with backend
- `/lib/screens` - UI screens for different app sections
  - `main_screen.dart` - Main application screen
  - `notes_screen.dart` - Notes management
  - `rss_screen.dart` - RSS feed reader
  - `llm_assistant_screen.dart` - LLM assistant interface
- `/lib/state` - State management with Provider
  - `app_state.dart` - Central application state
- `/lib/widgets` - Reusable UI components
  - `link_text.dart` - Text with note linking support
  - `note_link_editor.dart` - Editor for note links
- `/lib/app.dart` - App configuration and theme
- `/lib/main.dart` - Application entry point

### Backend Structure (`/backend`)
- `main.py` - FastAPI application and endpoints
- `llm_assistant.py` - LLM integration for note querying
- `models/` - Directory for GGUF model files
- `test_main.py` - Backend tests
- `pyproject.toml` - Python dependencies

### Documentation (`/descriptions`)
- `main.md` - Project overview and roadmap
- `local_llm_assistant.md` - LLM assistant implementation details
- `note_linking_with_database.md` - Database-driven note linking approach
- `simple_note_linking.md` - Simple note linking implementation

## Data Flow

1. **Note Creation & Management**:
   - User creates notes in Flutter UI
   - Notes are sent to backend via API service
   - Backend stores notes in SQLite database
   - Notes can be retrieved, updated, and deleted

2. **RSS Feed Processing**:
   - User adds RSS feed URLs in Flutter UI
   - Backend fetches and parses feeds
   - Feed items are displayed in the UI

3. **Note Linking**:
   - Links between notes use `[link text](note:note_id)` syntax
   - Backend parses links when retrieving notes
   - Frontend renders links as clickable text

4. **LLM Assistant**:
   - Local language models process user queries
   - Notes are used as context for answering questions
   - Vector embeddings enable semantic search

## Platform Support
The application is designed to run on multiple platforms:
- Mobile (Android/iOS)
- Web
- Desktop (Linux/macOS/Windows)

## Development Workflow
1. Backend and frontend can be developed independently
2. New features should be documented in `/descriptions` directory
3. Follow test-driven development for new functionality