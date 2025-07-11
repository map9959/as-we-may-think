# As We May Think

## Overview

As We May Think is an attempt to recreate the Memex (Memory Expander) from the opinion editorial of Vannevar Bush from 1945. The application is designed to help users collect, organize, and revisit their thoughts, notes, and information streams in a way that is visually inspired by classic typewriters and old paper.

## Frontend

This is the frontend to As We May Think, written in Flutter. There will be a backend written in Python.

### General Appearance

The theme of this program is loosely based on a typewriter with minimal distractions. It uses a serif font, and has a color scheme reminiscent of old paper. The interface is clean, with rounded corners and soft shadows, evoking a sense of nostalgia and focus.

### Main Screen

#### Main Functionality

- A large textbox is anchored at the bottom of the screen, spanning nearly the entire width, with rounded corners and a subtle background.
- When a user submits a new note, a modal dialog appears in the center of the screen. This modal expands smoothly and contains:
  - An editable title field at the top (pre-filled with the first line of the note).
  - A large, editable text area for the note content.
  - Save and Cancel buttons at the bottom right.
- The note is only saved if the user clicks Save. Cancel closes the modal without saving.

#### Sidebar

- The sidebar opens when the menu button in the top left is pressed.
- It contains navigation options for the Main screen, Notes screen, and RSS list.
- The sidebar is styled to match the overall theme and can be collapsed for a distraction-free experience.

#### "Connect to Outside World"

- A small slider in the top right labeled "Connect to outside world".
- When enabled, the top part of the main screen displays a horizontally scrolling list of story cards, sourced from user-added RSS feeds.
- Each card shows a story title and feed source, and can be clicked to view more details in a modal.

### Notes Screen

#### Behavior

- Displays a list of note titles.
- Clicking a title expands the note with an animation, showing the full content and metadata.
- Notes are sorted by creation date, with the newest at the top.

### RSS Screen

#### Behavior

- Shows a list of RSS feeds the user has added.
- A plus button in the top right opens a modal to add a new RSS feed.
- Import and download buttons allow users to manage their feed list.
- Each feed can be edited or removed.

## Backend

The backend is implemented in Python using FastAPI and SQLModel. It provides a REST API for managing notes and RSS feeds, supporting the following features:

- **Notes**: Create, retrieve, and delete notes. Notes are stored with the following attributes:
  - `id`: Unique UUID identifier (string)
  - `title`: Required non-empty string
  - `content`: Required non-empty string
  - `created_at`: ISO-formatted timestamp automatically added when a note is created
  
  The API supports:
  - `GET /notes`: List all notes (sorted by creation date, newest first)
  - `POST /notes`: Add a new note (requires title and content)
  - `DELETE /notes/{note_id}`: Delete a note by ID

- **RSS Feeds**: Add, list, and remove RSS feeds. Each feed has:
  - `id`: Auto-incrementing integer
  - `url`: Required URL string
  - `title`: Optional string
  
  The API allows users to:
  - `GET /feeds`: Retrieve all feeds
  - `POST /feeds`: Add a new feed
  - `DELETE /feeds/{feed_id}`: Delete a feed by ID

- **Feed Items**: For each RSS feed, the backend can fetch and parse the latest items:
  - `GET /feeds/{feed_id}/items`: Get items from a specific feed
  - `GET /stories`: Get aggregated items from all feeds, sorted by publication date (newest first)
  
  Each story item includes title, link, published date, summary, and feed source.

The backend uses an SQLite database (with async support via aiosqlite) and is designed to be easily extensible for future features such as advanced search, linking, and export/import. Data validation is performed using Pydantic field validators to ensure data integrity.

## User Experience

- The app is designed for minimal distraction and maximum focus on content.
- All modals and dialogs are centered and styled consistently.
- Keyboard shortcuts are supported for quick note entry and navigation.
- The interface is responsive and works across desktop and mobile devices.

## Future Plans

### Near Future

- Linking between notes
  - using markdown links in `[text](id)` format to link from one note to another.
- Notes based on articles
  - A user can highlight a section of a story they find in their RSS feed, and a tooltip pops up to take a note on it. The user presses an on-screen tooltip or a hotkey, and can write a note with that section quoted in the body of the note.
- Export and import options for notes and feeds
  - A user can download a list of their notes or feeds as a JSON list file.
  - A user can upload a list of feeds or notes in a similar manner to add to their database.
- More customization options for appearance and behavior
  - Background color options (light mode, dark mode)

### Medium Future

- AI auto-tagging system
  - Using semantic clustering (run locally on computer) to find the most similar notes to a given note.
  - Making tags that group notes together automatically.
- AI query system
  - Asking a small language model (run locally on computer) natural language queries to summarize articles, retrieve and summarize notes based on a given subject, or retrieve and summarize notes based on a given time period.
  - Also acts as a rudimentary personal assistant.

### Long-term Future

- Authentication
  - AI features will be done locally, but backend can be synced to a cloud service, requiring authentication.
- Encryption
  - The database will be stored locally, but can be synced to a cloud service and will be encrypted end-to-end and at rest.