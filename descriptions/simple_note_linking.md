# Simple Note Linking Implementation

## Overview

This implementation provides a straightforward way to create links between notes using a simple Markdown-style syntax. Unlike the database-driven approach described in `note_linking_with_database.md`, this implementation focuses on simplicity by parsing links directly from note content when needed, without requiring a separate database table for link tracking.

## Implementation Details

### Link Syntax

Links between notes will use the following Markdown-style syntax:

```
[link text](note:note_id)
```

Where:
- `link text` is the text displayed for the link
- `note_id` is the UUID of the target note

Example:
```
Check out my [research on butterflies](note:550e8400-e29b-41d4-a716-446655440000)
```

### Backend Implementation

#### Enhanced Note Model

The existing Note model doesn't need to change:

```python
class Note(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    title: str
    content: str
    created_at: Optional[str] = Field(default_factory=lambda: datetime.now().isoformat())
```

#### Enhanced Note Retrieval

When retrieving a note, we'll parse its content to find links:

```python
@app.get("/notes/{note_id}", response_model=dict)
async def get_note(note_id: str, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    # Find all outgoing links in the note content
    outgoing_links = []
    link_pattern = r'\[(.+?)\]\(note:([a-f0-9-]+)\)'
    for match in re.finditer(link_pattern, note.content):
        link_text, target_id = match.groups()
        
        # Check if target note exists
        target_note = await session.get(Note, target_id)
        if target_note:
            outgoing_links.append({
                "id": target_id,
                "title": target_note.title,
                "link_text": link_text
            })
    
    # Find all incoming links (notes that link to this one)
    incoming_links = []
    query = select(Note).where(Note.content.like(f"%note:{note_id}%"))
    result = await session.exec(query)
    source_notes = result.all()
    
    for source_note in source_notes:
        # For each note that might link to this one, extract the link text
        for match in re.finditer(link_pattern, source_note.content):
            link_text, target_id = match.groups()
            if target_id == note_id:
                incoming_links.append({
                    "id": source_note.id,
                    "title": source_note.title,
                    "link_text": link_text
                })
    
    return {
        "note": note,
        "outgoing_links": outgoing_links,
        "incoming_links": incoming_links
    }
```

#### Link Validation During Note Updates

When updating a note, we can optionally validate that links point to existing notes:

```python
@app.put("/notes/{note_id}", response_model=Note)
async def update_note(note_id: str, note_data: dict, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    if "title" in note_data:
        note.title = note_data["title"]
    if "content" in note_data:
        note.content = note_data["content"]
        
        # Optional: Validate links point to existing notes
        link_pattern = r'\[(.+?)\]\(note:([a-f0-9-]+)\)'
        for match in re.finditer(link_pattern, note.content):
            _, target_id = match.groups()
            target_note = await session.get(Note, target_id)
            if not target_note:
                # Could either warn the user or silently continue
                pass
    
    await session.commit()
    await session.refresh(note)
    return note
```

### Frontend Implementation

#### Displaying Notes with Links

When displaying a note, we'll render the content with clickable links:

```dart
class NoteContentWidget extends StatelessWidget {
  final String content;
  final Function(String) onNoteLinkTap;
  
  const NoteContentWidget({
    required this.content,
    required this.onNoteLinkTap,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final LinkTextSpan linkTextSpan = LinkTextSpan(
      text: content,
      linkPattern: RegExp(r'\[(.+?)\]\(note:([a-f0-9-]+)\)'),
      onLinkTap: (noteId) => onNoteLinkTap(noteId),
    );
    
    return SelectableText.rich(linkTextSpan);
  }
}

class LinkTextSpan extends TextSpan {
  LinkTextSpan({
    required String text,
    required RegExp linkPattern,
    required Function(String) onLinkTap,
    TextStyle? style,
  }) : super(
    style: style,
    children: _buildTextSpans(text, linkPattern, onLinkTap),
  );
  
  static List<TextSpan> _buildTextSpans(
    String text, 
    RegExp linkPattern,
    Function(String) onLinkTap,
  ) {
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    
    for (final match in linkPattern.allMatches(text)) {
      // Add text before the link
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      
      final linkText = match.group(1)!;
      final noteId = match.group(2)!;
      
      // Add the clickable link
      spans.add(
        TextSpan(
          text: linkText,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onLinkTap(noteId),
        ),
      );
      
      lastIndex = match.end;
    }
    
    // Add any remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    
    return spans;
  }
}
```

#### Note Editor with Link Support

In the note editor, we'll add a button to insert links to other notes:

```dart
class NoteEditorScreen extends StatefulWidget {
  final String? initialContent;
  final Function(String, String) onSave;
  
  const NoteEditorScreen({
    this.initialContent,
    required this.onSave,
    Key? key,
  }) : super(key: key);
  
  @override
  _NoteEditorScreenState createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  void _insertNoteLink() async {
    // Show dialog to select a note to link to
    final selectedNote = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => NoteSelectionDialog(),
    );
    
    if (selectedNote != null) {
      final noteId = selectedNote['id']!;
      final noteTitle = selectedNote['title']!;
      
      // Insert link at current cursor position
      final currentText = _contentController.text;
      final selection = _contentController.selection;
      
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        '[$noteTitle](note:$noteId)',
      );
      
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + noteTitle.length + noteId.length + 10,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Note'),
        actions: [
          IconButton(
            icon: Icon(Icons.link),
            onPressed: _insertNoteLink,
            tooltip: 'Insert link to another note',
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              widget.onSave(
                _titleController.text,
                _contentController.text,
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteSelectionDialog extends StatefulWidget {
  @override
  _NoteSelectionDialogState createState() => _NoteSelectionDialogState();
}

class _NoteSelectionDialogState extends State<NoteSelectionDialog> {
  List<Map<String, String>> _notes = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotes();
  }
  
  Future<void> _loadNotes() async {
    try {
      final apiService = ApiService();
      final notes = await apiService.getNotes();
      
      setState(() {
        _notes = notes.map((note) => {
          'id': note.id,
          'title': note.title,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Note to Link',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return ListTile(
                          title: Text(note['title']!),
                          onTap: () {
                            Navigator.of(context).pop(note);
                          },
                        );
                      },
                    ),
                  ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Displaying Linked Notes Section

When viewing a note, we'll show sections for outgoing and incoming links:

```dart
class LinkedNotesSection extends StatelessWidget {
  final List<Map<String, dynamic>> outgoingLinks;
  final List<Map<String, dynamic>> incomingLinks;
  final Function(String) onNoteTap;
  
  const LinkedNotesSection({
    required this.outgoingLinks,
    required this.incomingLinks,
    required this.onNoteTap,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outgoingLinks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Links to:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...outgoingLinks.map((link) => ListTile(
            title: Text(link['title'] as String),
            subtitle: Text('as "${link['link_text']}"'),
            onTap: () => onNoteTap(link['id'] as String),
          )),
        ],
        
        if (incomingLinks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Referenced from:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...incomingLinks.map((link) => ListTile(
            title: Text(link['title'] as String),
            subtitle: Text('as "${link['link_text']}"'),
            onTap: () => onNoteTap(link['id'] as String),
          )),
        ],
      ],
    );
  }
}
```

## Advantages of This Approach

1. **Simplicity**: No additional database tables or complex relationships to manage.

2. **Implementation Speed**: Can be quickly implemented without changes to the database schema.

3. **No Migration Required**: Existing notes don't need to be modified or migrated.

4. **Flexibility**: Links are parsed on demand, allowing for different link formats if needed.

5. **Self-Contained**: All link information is contained within the note content itself.

## Limitations

1. **Performance**: For large numbers of notes, scanning for backlinks may become slow.

2. **Orphaned Links**: If a note is deleted, links to it will become broken with no automatic cleanup.

3. **No Link Metadata**: Cannot store additional data about links beyond what's in the text itself.

4. **Consistency Issues**: Links may become inconsistent if note IDs change.

## Implementation Steps

1. **Backend**: 
   - Enhance the note retrieval API to parse and validate links
   - Optionally add link validation to note creation/update APIs

2. **Frontend**:
   - Create a rich text rendering component for note content with links
   - Add a UI for inserting links to other notes
   - Add UI components to display linked notes

3. **Testing**:
   - Test link creation, validation, and navigation
   - Verify performance with larger note collections