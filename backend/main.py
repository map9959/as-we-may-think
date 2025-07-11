from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from sqlmodel import Field, SQLModel, select
from sqlmodel.ext.asyncio.session import AsyncSession
from typing import Optional, List, AsyncGenerator, Dict, Any
from fastapi import Depends, status
from pydantic import field_validator, BaseModel
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from contextlib import asynccontextmanager
import feedparser
import httpx
import uuid
from datetime import datetime
import os
import shutil
from llm_assistant import LLMAssistant

DATABASE_URL = "sqlite+aiosqlite:///aswm_backend.db"
MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

# Create models directory if it doesn't exist
os.makedirs(MODELS_DIR, exist_ok=True)

def get_engine(database_url=DATABASE_URL):
    return create_async_engine(database_url, echo=True, future=True)

engine = get_engine()

# Initialize LLM Assistant
llm_assistant = LLMAssistant()

# LLM Assistant models
class LLMQuery(BaseModel):
    query: str
    max_tokens: Optional[int] = 512

class LLMResponse(BaseModel):
    answer: str
    sources: Optional[List[Dict[str, Any]]] = []

class ModelInfo(BaseModel):
    name: str
    path: str
    is_active: bool

class NoteBase(SQLModel):
    title: str
    content: str
    
    @field_validator('title')
    @classmethod
    def title_must_not_be_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Title cannot be empty')
        return v.strip()
    
    @field_validator('content')
    @classmethod
    def content_must_not_be_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Content cannot be empty')
        return v.strip()

class Note(NoteBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    created_at: Optional[str] = Field(default_factory=lambda: datetime.now().isoformat(), index=True)

class NoteCreate(NoteBase):
    pass

class Feed(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    url: str
    title: Optional[str] = None

async def init_db(engine_to_use=None):
    if engine_to_use is None:
        engine_to_use = engine
    async with engine_to_use.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(lifespan=lifespan)

async def get_session(engine_to_use=None) -> AsyncGenerator[AsyncSession, None]:
    if engine_to_use is None:
        engine_to_use = engine
    async with AsyncSession(engine_to_use) as session:
        yield session

@app.get("/")
async def root():
    return {"message": "As We May Think backend is running!"}

@app.get("/notes", response_model=List[Note])
async def get_notes(session: AsyncSession = Depends(get_session)):
    result = await session.exec(select(Note).order_by(Note.created_at.desc()))
    return result.all()

@app.post("/notes", response_model=Note, status_code=status.HTTP_201_CREATED)
async def add_note(note: NoteCreate, session: AsyncSession = Depends(get_session)):
    new_note = Note.model_validate(note.model_dump())
    session.add(new_note)
    await session.commit()
    await session.refresh(new_note)
    return new_note

@app.delete("/notes/{note_id}", response_model=None, status_code=204)
async def delete_note(note_id: str, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    await session.delete(note)
    await session.commit()

@app.get("/notes/search", response_model=List[Note])
async def search_notes(query: str = Query(...), session: AsyncSession = Depends(get_session)):
    """
    Search for notes by title for autocomplete suggestions when creating links.
    Returns a list of notes whose titles contain the search query.
    """
    search_query = f"%{query}%"
    result = await session.exec(
        select(Note).where(Note.title.like(search_query)).order_by(Note.created_at.desc()).limit(10)
    )
    return result.all()

@app.post("/feeds", response_model=Feed)
async def add_feed(feed: Feed, session: AsyncSession = Depends(get_session)):
    session.add(feed)
    await session.commit()
    await session.refresh(feed)
    return feed

@app.get("/feeds", response_model=List[Feed])
async def get_feeds(session: AsyncSession = Depends(get_session)):
    result = await session.exec(select(Feed))
    return result.all()

@app.delete("/feeds/{feed_id}", response_model=None, status_code=204)
async def delete_feed(feed_id: int, session: AsyncSession = Depends(get_session)):
    feed = await session.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    await session.delete(feed)
    await session.commit()

@app.get("/feeds/{feed_id}/items")
async def get_feed_items(feed_id: int, session: AsyncSession = Depends(get_session)):
    feed = await session.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    async with httpx.AsyncClient() as client:
        response = await client.get(feed.url)
        response.raise_for_status()
        parsed = feedparser.parse(response.text)
    items = [
        {
            "title": entry.get("title"),
            "link": entry.get("link"),
            "published": entry.get("published"),
            "summary": entry.get("summary"),
        }
        for entry in parsed.entries
    ]
    return {"items": items}

@app.get("/stories")
async def get_all_stories(session: AsyncSession = Depends(get_session)):
    result = await session.exec(select(Feed))
    feeds = result.all()
    all_items = []
    async with httpx.AsyncClient() as client:
        for feed in feeds:
            try:
                response = await client.get(feed.url)
                response.raise_for_status()
                parsed = feedparser.parse(response.text)
                for entry in parsed.entries:
                    all_items.append({
                        "title": entry.get("title"),
                        "link": entry.get("link"),
                        "published": entry.get("published"),
                        "summary": entry.get("summary"),
                        "feed_title": feed.title or feed.url
                    })
            except Exception:
                continue
    # Sort by published date if available, else unsorted
    def parse_date(item):
        from dateutil import parser
        try:
            return parser.parse(item["published"]) if item["published"] else None
        except Exception:
            return None
    all_items.sort(key=lambda x: parse_date(x) or "", reverse=True)
    return {"items": all_items}

# LLM Assistant endpoints

@app.post("/llm/ask", response_model=LLMResponse)
async def ask_llm(query: LLMQuery, session: AsyncSession = Depends(get_session)):
    """
    Ask a question to the LLM assistant.
    
    The assistant will search for relevant notes and use them as context for answering.
    """
    # Get all notes to use as context
    result = await session.exec(select(Note))
    notes = result.all()
    
    # Convert notes to the format expected by the LLM assistant
    documents = [
        {
            "id": note.id,
            "title": note.title,
            "content": note.content,
            "created_at": note.created_at
        }
        for note in notes
    ]
    
    # Index the documents in the LLM assistant
    llm_assistant.index_documents(documents)
    
    # Generate a response
    if llm_assistant.model:
        response = llm_assistant.answer_with_context(query.query, query.max_tokens)
        return response
    else:
        # If no model is loaded, just return search results
        sources = llm_assistant.search_documents(query.query, top_k=5)
        return {
            "answer": "No LLM model is currently loaded. Please upload a model first.",
            "sources": sources
        }

@app.get("/llm/models", response_model=List[ModelInfo])
async def list_models():
    """List available LLM models."""
    models = []
    active_model = os.path.basename(llm_assistant.model_path) if llm_assistant.model_path else None
    
    # Get list of .gguf files in the models directory
    if os.path.exists(MODELS_DIR):
        for filename in os.listdir(MODELS_DIR):
            if filename.endswith(".gguf"):
                model_path = os.path.join(MODELS_DIR, filename)
                models.append({
                    "name": filename,
                    "path": model_path,
                    "is_active": filename == active_model
                })
    
    return models

@app.post("/llm/models/upload")
async def upload_model(
    file: UploadFile = File(...),
    model_name: str = Form(...),
):
    """Upload a new LLM model."""
    # Ensure valid file
    if not file.filename.endswith(".gguf"):
        raise HTTPException(
            status_code=400, 
            detail="Invalid model file. Only .gguf files are supported."
        )
    
    # Determine save path, using provided name or original filename
    save_name = model_name.strip() if model_name else file.filename
    if not save_name.endswith(".gguf"):
        save_name += ".gguf"
    
    save_path = os.path.join(MODELS_DIR, save_name)
    
    # Save the uploaded file
    with open(save_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    return {"message": f"Model {save_name} uploaded successfully", "path": save_path}

@app.post("/llm/models/activate/{model_name}")
async def activate_model(model_name: str):
    """Set the active LLM model."""
    model_path = os.path.join(MODELS_DIR, model_name)
    
    if not os.path.exists(model_path):
        raise HTTPException(
            status_code=404,
            detail=f"Model {model_name} not found"
        )
    
    # Load the model with improved error handling
    success, error_msg = llm_assistant.set_model_path(model_path)
    
    if not success:
        raise HTTPException(
            status_code=500,
            detail=error_msg
        )
    
    return {"message": f"Model {model_name} activated successfully"}

@app.delete("/llm/models/{model_name}")
async def delete_model(model_name: str):
    """Delete an LLM model."""
    model_path = os.path.join(MODELS_DIR, model_name)
    
    if not os.path.exists(model_path):
        raise HTTPException(
            status_code=404,
            detail=f"Model {model_name} not found"
        )
    
    # Check if model is active
    if llm_assistant.model_path == model_path:
        # Clear the model from memory
        llm_assistant.model = None
        llm_assistant.model_path = None
    
    # Delete the file
    os.remove(model_path)
    
    return {"message": f"Model {model_name} deleted successfully"}
