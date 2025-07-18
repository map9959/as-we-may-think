# Design Document: Note Linking Feature

## Overview

The note linking feature implements a Markdown-style syntax for creating links between notes. This document outlines the design decisions, components, and interactions needed to implement this feature effectively.

## Architecture

The note linking feature follows a simple architecture that integrates with the existing application:

1. **Frontend Components**:
   - `NoteLinkEditor`: A custom text editor that detects link patterns and shows suggestions
   - `LinkText`: A text rendering component that displays clickable links
   - Note navigation logic in the `NotesScreen`

2. **Backend Components**:
   - Note search endpoint for finding notes while creating links
   - Standard note CRUD operations (no special backend changes needed)

3. **Data Flow**:
   - User types link syntax → Editor detects pattern → Dropdown shows suggestions
   - User selects note → Link is inserted → User saves note
   - User views note → Links are rendered as clickable text
   - User clicks link → Application navigates to linked note

## Components and Interfaces

### NoteLinkEditor Widget

The `NoteLinkEditor` is a custom widget that extends the standard TextField with link detection and suggestion capabilities:

```dart
class NoteLinkEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  
  // Constructor and createState implementation
}

class _NoteLinkEditorState extends State<NoteLinkEditor> {
  // State variables for suggestions, loading state, etc.
  
  // Methods:
  // - _onTextChanged(): Detect cursor position changes and check for link patterns
  // - _checkForLinkTyping(): Detect if user is typing a link pattern
  // - _searchNotes(): Query backend for note suggestions
  // - _selectNote(): Insert selected note as a link
  // - build(): Render editor with overlay for suggestions
}
```

### LinkText Widget

The `LinkText` widget renders text with embedded links as clickable spans:

```dart
class LinkText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String) onNoteLinkTap;
  
  // Constructor
  
  // Methods:
  // - _buildTextSpans(): Parse text and create spans with clickable links
  // - build(): Render rich text with spans
}
```

### API Interface

The existing `ApiService` class will be used with the following method:

```dart
Future<List<dynamic>> searchNotes(String query) async {
  // Search notes by title/content and return results
}
```

## Data Models

### Link Pattern

Links will follow this syntax: `[link text](note:note_id)`

- `link text`: The displayed text for the link
- `note_id`: The UUID of the target note

### Regular Expressions

Two key regular expressions will be used:

1. For detecting when a user is typing a link:
   ```
   \[([^\]]+)\]\($
   ```

2. For detecting when a user is typing a note ID:
   ```
   \[([^\]]+)\]\(note:([a-zA-Z0-9-]*)$
   ```

3. For parsing links in displayed text:
   ```
   \[(.+?)\]\(note:([a-zA-Z0-9-]+)\)
   ```

## Error Handling

1. **Non-existent Notes**:
   - When a user clicks a link to a non-existent note, show a snackbar message
   - If a note is filtered out by search, offer to clear the search

2. **Invalid Link Syntax**:
   - The editor will only show suggestions for valid link patterns
   - The link renderer will ignore malformed links

## Testing Strategy

1. **Unit Tests**:
   - Test regular expressions for link detection
   - Test link parsing and rendering logic

2. **Widget Tests**:
   - Test `NoteLinkEditor` suggestion display
   - Test `LinkText` rendering and tap handling

3. **Integration Tests**:
   - Test end-to-end flow of creating and navigating links
   - Test search functionality during link creation