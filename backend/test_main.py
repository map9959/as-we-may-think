import pytest
import pytest_asyncio
import httpx
import unittest.mock
from main import app, get_engine, init_db, get_session
from sqlmodel.ext.asyncio.session import AsyncSession
from fastapi import Depends
import uuid

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture(scope="function", autouse=True)
async def test_app():
    # Create a new engine and initialize the in-memory DB for each test
    test_engine = get_engine(TEST_DATABASE_URL)
    await init_db(test_engine)
    # Correctly override the get_session dependency
    async def override_get_session():
        async with AsyncSession(test_engine) as session:
            yield session
    app.dependency_overrides[get_session] = override_get_session
    yield
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_root():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        response = await ac.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "As We May Think backend is running!"}

@pytest.mark.asyncio
async def test_add_and_get_notes():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a note
        note_data = {"title": "Test Note Title", "content": "Test note"}
        response = await ac.post("/notes", json=note_data)
        assert response.status_code == 201
        note = response.json()
        assert note["title"] == "Test Note Title"
        assert note["content"] == "Test note"
        # Get notes
        response = await ac.get("/notes")
        assert response.status_code == 200
        notes = response.json()
        assert any(n["content"] == "Test note" for n in notes)

@pytest.mark.asyncio
async def test_add_and_get_feeds():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a feed
        feed_data = {"url": "https://example.com/rss.xml", "title": "Example Feed"}
        response = await ac.post("/feeds", json=feed_data)
        assert response.status_code == 200
        feed = response.json()
        assert feed["url"] == "https://example.com/rss.xml"
        assert feed["title"] == "Example Feed"
        # Get feeds
        response = await ac.get("/feeds")
        assert response.status_code == 200
        feeds = response.json()
        assert any(f["url"] == "https://example.com/rss.xml" for f in feeds)

@pytest.mark.asyncio
async def test_delete_note():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a note
        note_data = {"title": "Delete Note", "content": "Delete me"}
        response = await ac.post("/notes", json=note_data)
        note = response.json()
        note_id = note["id"]
        # Delete the note
        response = await ac.delete(f"/notes/{note_id}")
        assert response.status_code == 204
        # Ensure it's gone
        response = await ac.get("/notes")
        notes = response.json()
        assert not any(n["id"] == note_id for n in notes)

@pytest.mark.asyncio
async def test_delete_feed():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a feed
        feed_data = {"url": "https://delete-feed.com/rss.xml", "title": "Delete Feed"}
        response = await ac.post("/feeds", json=feed_data)
        feed = response.json()
        feed_id = feed["id"]
        # Delete the feed
        response = await ac.delete(f"/feeds/{feed_id}")
        assert response.status_code == 204
        # Ensure it's gone
        response = await ac.get("/feeds")
        feeds = response.json()
        assert not any(f["id"] == feed_id for f in feeds)

@pytest.mark.asyncio
async def test_get_feed_items(monkeypatch):
    # Mock feedparser.parse to avoid real HTTP requests
    class DummyEntry:
        def get(self, key):
            return {"title": "Test Item", "link": "http://item", "published": "2025-04-18", "summary": "Summary"}.get(key)
    class DummyParsed:
        entries = [DummyEntry()]
    monkeypatch.setattr("feedparser.parse", lambda text: DummyParsed())

    class DummyResponse:
        text = ""
        status_code = 200
        def raise_for_status(self):
            pass
        def json(self):
            return {"items": [{
                "title": "Test Item",
                "link": "http://item",
                "published": "2025-04-18",
                "summary": "Summary"
            }]}
    async def dummy_get(self, url, *args, **kwargs):
        return DummyResponse()

    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a feed
        feed_data = {"url": "https://mock-feed.com/rss.xml", "title": "Mock Feed"}
        response = await ac.post("/feeds", json=feed_data)
        feed = response.json()
        feed_id = feed["id"]

        # Patch only for the app's internal fetch
        with unittest.mock.patch("httpx.AsyncClient.get", dummy_get):
            response = await ac.get(f"/feeds/{feed_id}/items")
            assert response.status_code == 200
            items = response.json()["items"]
            assert items[0]["title"] == "Test Item"

@pytest.mark.asyncio
async def test_note_uuid_generation():
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a note
        note_data = {"title": "UUID Test Note", "content": "UUID test note"}
        response = await ac.post("/notes", json=note_data)
        assert response.status_code == 201
        note = response.json()
        
        # Verify that the ID is a valid UUID
        note_id = note["id"]
        try:
            # This will raise an exception if the ID is not a valid UUID
            uuid_obj = uuid.UUID(note_id)
            assert str(uuid_obj) == note_id  # Verify string representation matches
        except ValueError:
            pytest.fail(f"Note ID '{note_id}' is not a valid UUID")
        
        # Add a second note and verify it gets a different UUID
        note_data2 = {"title": "Second UUID Test", "content": "Second UUID test note"}
        response2 = await ac.post("/notes", json=note_data2)
        note2 = response2.json()
        assert note2["id"] != note["id"]  # IDs should be different
        
        # Verify we can fetch the note by UUID
        response = await ac.get("/notes")
        notes = response.json()
        assert any(n["id"] == note_id and n["content"] == "UUID test note" for n in notes)

@pytest.mark.asyncio
async def test_note_with_title_and_content():
    """Test that notes properly handle separate title and content fields."""
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add a note with title and content
        note_data = {"title": "Test Title", "content": "Test content body"}
        response = await ac.post("/notes", json=note_data)
        assert response.status_code == 201  # Updated from 200 to 201
        note = response.json()
        
        # Verify both fields were stored correctly
        assert note["title"] == "Test Title"
        assert note["content"] == "Test content body"
        
        # Get notes and verify the fields are preserved
        response = await ac.get("/notes")
        assert response.status_code == 200
        notes = response.json()
        matching_notes = [n for n in notes if n["id"] == note["id"]]
        assert len(matching_notes) == 1
        assert matching_notes[0]["title"] == "Test Title"
        assert matching_notes[0]["content"] == "Test content body"

@pytest.mark.asyncio
async def test_uuid_validation_edge_cases():
    """Test UUID generation and validation with edge cases."""
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add multiple notes and ensure all UUIDs are valid and unique
        uuids = set()
        for i in range(5):
            note_data = {"title": f"UUID Test {i}", "content": f"UUID test content {i}"}
            response = await ac.post("/notes", json=note_data)
            assert response.status_code == 201  # Updated from 200 to 201
            note = response.json()
            note_id = note["id"]
            
            # Verify it's a valid UUID
            try:
                uuid_obj = uuid.UUID(note_id)
                # Check UUID version (should be version 4 - random)
                assert uuid_obj.version == 4
            except ValueError:
                pytest.fail(f"Generated ID '{note_id}' is not a valid UUID")
            
            # Check uniqueness
            assert note_id not in uuids, f"UUID {note_id} was generated more than once"
            uuids.add(note_id)
            
        # Attempt to use an invalid UUID format for deletion
        response = await ac.delete("/notes/not-a-valid-uuid")
        assert response.status_code == 404  # Should not be found, not cause a server error

@pytest.mark.asyncio
async def test_notes_sorting_by_created_date():
    """Test that notes are properly sorted by creation date (newest first)."""
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Add multiple notes with a small delay between them
        import asyncio
        note_ids = []
        for i in range(3):
            note_data = {"title": f"Sorting Test {i}", "content": f"Content {i}"}
            response = await ac.post("/notes", json=note_data)
            assert response.status_code == 201  # Changed from 200 to 201
            note = response.json()
            note_ids.append(note["id"])
            # Add a small delay to ensure different creation timestamps
            await asyncio.sleep(0.01)
        
        # Get notes and verify they're returned newest first
        response = await ac.get("/notes")
        assert response.status_code == 200
        notes = response.json()
        
        # Extract the notes we just created (should be the first 3)
        retrieved_notes = [n for n in notes if n["id"] in note_ids]
        assert len(retrieved_notes) == 3
        
        # Verify they're in reverse order of creation (newest first)
        for i in range(len(retrieved_notes) - 1):
            # Parse ISO format dates for comparison
            current_date = retrieved_notes[i]["created_at"]
            next_date = retrieved_notes[i + 1]["created_at"]
            # Ensure current timestamp is later than or equal to next timestamp
            assert current_date >= next_date

@pytest.mark.asyncio
async def test_note_field_validation_and_defaults():
    """Test handling of missing fields and validation in notes."""
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Test with only title provided (FastAPI should validate this before it reaches the database)
        title_only_data = {"title": "Title Only Test"}
        response = await ac.post("/notes", json=title_only_data)
        assert response.status_code == 422  # Should fail validation - content is required
        
        # Test with only content provided
        content_only_data = {"content": "Content Only Test"}
        response = await ac.post("/notes", json=content_only_data)
        assert response.status_code == 422  # Should fail validation - title is required
        
        # Test with empty strings
        empty_data = {"title": "", "content": ""}
        response = await ac.post("/notes", json=empty_data)
        assert response.status_code == 422  # Empty values should not pass validation
        
        # Test with valid data but verify created_at is auto-generated
        valid_data = {"title": "Complete Note", "content": "This note has all required fields"}
        response = await ac.post("/notes", json=valid_data)
        assert response.status_code == 201
        note = response.json()
        
        # Verify created_at was auto-generated and is in ISO format
        assert "created_at" in note
        assert note["created_at"] is not None
        # Quick check for ISO format (YYYY-MM-DDThh:mm:ss)
        assert len(note["created_at"]) > 16
        assert "T" in note["created_at"] or " " in note["created_at"]
        
        # Verify all fields are returned correctly
        assert note["title"] == "Complete Note"
        assert note["content"] == "This note has all required fields"
        assert "id" in note

@pytest.mark.asyncio
async def test_note_field_validation():
    """Test that the API properly validates note fields and returns 422 errors."""
    async with httpx.AsyncClient(
        base_url="http://test", transport=httpx.ASGITransport(app=app)
    ) as ac:
        # Test with only title provided
        title_only_data = {"title": "Title Only Test"}
        response = await ac.post("/notes", json=title_only_data)
        assert response.status_code == 422  # Should fail validation - content is required
        
        # Test with only content provided
        content_only_data = {"content": "Content Only Test"}
        response = await ac.post("/notes", json=content_only_data)
        assert response.status_code == 422  # Should fail validation - title is required
        
        # Test with empty strings
        empty_data = {"title": "", "content": ""}
        response = await ac.post("/notes", json=empty_data)
        assert response.status_code == 422  # Empty values should not pass validation
        
        # Test with valid data
        valid_data = {"title": "Complete Note", "content": "This note has all required fields"}
        response = await ac.post("/notes", json=valid_data)
        assert response.status_code == 201  # Created
        note = response.json()
        
        # Verify fields are returned correctly
        assert note["title"] == "Complete Note"
        assert note["content"] == "This note has all required fields"
        assert "id" in note
        assert "created_at" in note
