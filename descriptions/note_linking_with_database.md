# Note Linking Implementation with Database Tracking

## Overview

This implementation adds a database table to track links between notes, enabling proper data integrity and simplified management of links. When a note is deleted, any link relationships involving that note will be automatically removed.

## Database Schema Changes

### New NoteLink Model

```python
class NoteLink(SQLModel, table=True):
    __tablename__ = "note_links"
    
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    source_id: str = Field(foreign_key="notes.id")
    target_id: str = Field(foreign_key="notes.id")
    link_text: str
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
```

### Updated Note Model

```python
class Note(NoteBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    created_at: Optional[str] = Field(default_factory=lambda: datetime.now().isoformat(), index=True)
    
    # Relationships
    outgoing_links: List["NoteLink"] = Relationship(
        sa_relationship_kwargs={"primaryjoin": "Note.id==NoteLink.source_id", "cascade": "all, delete-orphan"}
    )
    incoming_links: List["NoteLink"] = Relationship(
        sa_relationship_kwargs={"primaryjoin": "Note.id==NoteLink.target_id", "cascade": "all, delete-orphan"}
    )
```

## API Implementation

### New Endpoint: Create Link

```python
@app.post("/notes/{source_id}/links", response_model=NoteLink)
async def create_link(
    source_id: str, 
    link_data: dict, 
    session: AsyncSession = Depends(get_session)
):
    source_note = await session.get(Note, source_id)
    if not source_note:
        raise HTTPException(status_code=404, detail="Source note not found")
    
    target_id = link_data.get("target_id")
    if not target_id:
        raise HTTPException(status_code=400, detail="Target note ID required")
    
    target_note = await session.get(Note, target_id)
    if not target_note:
        raise HTTPException(status_code=404, detail="Target note not found")
    
    link = NoteLink(
        source_id=source_id,
        target_id=target_id,
        link_text=link_data.get("link_text", target_note.title)
    )
    
    session.add(link)
    await session.commit()
    await session.refresh(link)
    return link
```

### Updated Note Creation

```python
@app.post("/notes", response_model=Note, status_code=status.HTTP_201_CREATED)
async def add_note(note: NoteCreate, session: AsyncSession = Depends(get_session)):
    new_note = Note.model_validate(note.model_dump())
    session.add(new_note)
    await session.commit()
    await session.refresh(new_note)
    
    # Process content for links
    link_pattern = r'\[(.+?)\]\(note:([a-f0-9-]+)\)'
    for match in re.finditer(link_pattern, note.content):
        link_text, target_id = match.groups()
        
        # Validate UUID format before querying
        try:
            uuid_obj = uuid.UUID(target_id)
            # Only create link if UUID is valid and target note exists
            target_note = await session.get(Note, target_id)
            if target_note:
                link = NoteLink(
                    source_id=new_note.id,
                    target_id=target_id,
                    link_text=link_text
                )
                session.add(link)
        except ValueError:
            # Invalid UUID - silently skip creating this link
            continue
    
    await session.commit()
    return new_note
```

### Enhanced Get Note Endpoint

```python
@app.get("/notes/{note_id}", response_model=dict)
async def get_note(note_id: str, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    # Get outgoing links
    outgoing_links_query = select(NoteLink).where(NoteLink.source_id == note_id)
    outgoing_links_result = await session.exec(outgoing_links_query)
    outgoing_links = outgoing_links_result.all()
    
    # Get incoming links (backlinks)
    incoming_links_query = select(NoteLink).where(NoteLink.target_id == note_id)
    incoming_links_result = await session.exec(incoming_links_query)
    incoming_links = incoming_links_result.all()
    
    # Format links with note titles
    formatted_outgoing = []
    for link in outgoing_links:
        target = await session.get(Note, link.target_id)
        if target:
            formatted_outgoing.append({
                "id": link.id,
                "target_id": link.target_id,
                "target_title": target.title,
                "link_text": link.link_text,
                "is_broken": False
            })
    
    formatted_incoming = []
    for link in incoming_links:
        source = await session.get(Note, link.source_id)
        if source:
            formatted_incoming.append({
                "id": link.id,
                "source_id": link.source_id,
                "source_title": source.title,
                "link_text": link.link_text,
                "is_broken": False
            })
    
    return {
        "note": note,
        "outgoing_links": formatted_outgoing,
        "incoming_links": formatted_incoming
    }
```

### Update Note Endpoint

```python
@app.put("/notes/{note_id}", response_model=Note)
async def update_note(
    note_id: str, 
    note_data: NoteCreate, 
    session: AsyncSession = Depends(get_session)
):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    # Update note data
    note.title = note_data.title
    note.content = note_data.content
    
    # Remove all existing outgoing links
    await session.exec(
        f"DELETE FROM note_links WHERE source_id = '{note_id}'"
    )
    
    # Process content for new links
    link_pattern = r'\[(.+?)\]\(note:([a-f0-9-]+)\)'
    for match in re.finditer(link_pattern, note_data.content):
        link_text, target_id = match.groups()
        
        # Validate UUID format before querying
        try:
            uuid_obj = uuid.UUID(target_id)
            # Only create link if UUID is valid and target note exists
            target_note = await session.get(Note, target_id)
            if target_note:
                link = NoteLink(
                    source_id=note_id,
                    target_id=target_id,
                    link_text=link_text
                )
                session.add(link)
        except ValueError:
            # Invalid UUID - silently skip creating this link
            continue
    
    await session.commit()
    await session.refresh(note)
    return note
```

### Enhanced Delete Note

```python
@app.delete("/notes/{note_id}", response_model=None, status_code=204)
async def delete_note(note_id: str, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    # The link deletions will happen automatically because of the cascade delete in the model
    await session.delete(note)
    await session.commit()
```

## Frontend Implementation

### Models

```dart
class Note {
  final String id;
  final String title;
  final String content;
  final String createdAt;
  
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });
  
  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    createdAt: json['created_at'],
  );
}

class NoteLink {
  final String id;
  final String sourceId;
  final String targetId;
  final String linkText;
  final String? targetTitle;  // Used for displaying outgoing links
  final String? sourceTitle;  // Used for displaying incoming links
  
  NoteLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.linkText,
    this.targetTitle,
    this.sourceTitle,
  });
  
  factory NoteLink.fromJson(Map<String, dynamic> json) => NoteLink(
    id: json['id'],
    sourceId: json['source_id'] ?? json['source_id'],
    targetId: json['target_id'] ?? json['target_id'],
    linkText: json['link_text'],
    targetTitle: json['target_title'],
    sourceTitle: json['source_title'],
  );
}

class NoteWithLinks {
  final Note note;
  final List<NoteLink> outgoingLinks;
  final List<NoteLink> incomingLinks;
  
  NoteWithLinks({
    required this.note,
    required this.outgoingLinks,
    required this.incomingLinks,
  });
  
  factory NoteWithLinks.fromJson(Map<String, dynamic> json) => NoteWithLinks(
    note: Note.fromJson(json['note']),
    outgoingLinks: (json['outgoing_links'] as List)
        .map((link) => NoteLink.fromJson(link))
        .toList(),
    incomingLinks: (json['incoming_links'] as List)
        .map((link) => NoteLink.fromJson(link))
        .toList(),
  );
}
```

### API Service

```dart
class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  
  // Get a note with links
  Future<NoteWithLinks> getNoteWithLinks(String noteId) async {
    final response = await _dio.get('/notes/$noteId');
    return NoteWithLinks.fromJson(response.data);
  }
  
  // Create a link between notes
  Future<NoteLink> createLink(String sourceId, String targetId, String linkText) async {
    final response = await _dio.post(
      '/notes/$sourceId/links',
      data: {
        'target_id': targetId,
        'link_text': linkText,
      },
    );
    return NoteLink.fromJson(response.data);
  }
  
  // Update a note (preserves links)
  Future<Note> updateNote(String noteId, String title, String content) async {
    final response = await _dio.put(
      '/notes/$noteId',
      data: {
        'title': title,
        'content': content,
      },
    );
    return Note.fromJson(response.data);
  }
}
```

### UI Component for Link Management

```dart
class LinkManagementSection extends StatelessWidget {
  final NoteWithLinks noteWithLinks;
  final Function(String) onNoteSelected;
  
  const LinkManagementSection({
    required this.noteWithLinks,
    required this.onNoteSelected,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (noteWithLinks.outgoingLinks.isNotEmpty) ...[
          Text('Linked To:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          ...noteWithLinks.outgoingLinks.map((link) => 
            ListTile(
              title: Text(link.targetTitle ?? 'Unknown Note'),
              subtitle: Text('as "${link.linkText}"'),
              onTap: () => onNoteSelected(link.targetId),
            ),
          ),
          Divider(),
        ],
        
        if (noteWithLinks.incomingLinks.isNotEmpty) ...[
          Text('Referenced From:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          ...noteWithLinks.incomingLinks.map((link) => 
            ListTile(
              title: Text(link.sourceTitle ?? 'Unknown Note'),
              subtitle: Text('as "${link.linkText}"'),
              onTap: () => onNoteSelected(link.sourceId),
            ),
          ),
        ],
      ],
    );
  }
}
```

### Text Processing

The frontend needs to process text to:

1. Render links when viewing notes, indicating broken links:

```dart
Widget buildNoteContent(String content, Function(String) onLinkTap, {required Set<String> activeLinks}) {
  final RegExp linkPattern = RegExp(r'\[(.+?)\]\(note:([a-f0-9-]+)\)');
  final matches = linkPattern.allMatches(content);
  
  if (matches.isEmpty) {
    return Text(content);
  }
  
  final List<InlineSpan> spans = [];
  int lastEnd = 0;
  
  for (final match in matches) {
    // Add text before link
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
    }
    
    final linkText = match.group(1)!;
    final noteId = match.group(2)!;
    
    // Check if the link is valid (either from cache or API)
    final isValid = activeLinks.contains(noteId);
    
    // Add link with appropriate styling
    spans.add(TextSpan(
      text: linkText,
      style: TextStyle(
        color: isValid ? Colors.blue : Colors.red,
        decoration: TextDecoration.underline,
        decorationStyle: isValid ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          if (isValid) {
            onLinkTap(noteId);
          } else {
            // Show broken link message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Link to deleted or non-existent note'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
    ));
    
    lastEnd = match.end;
  }
  
  // Add remaining text
  if (lastEnd < content.length) {
    spans.add(TextSpan(text: content.substring(lastEnd)));
  }
  
  return RichText(text: TextSpan(children: spans));
}
```

2. Validate links when displaying:

```dart
class NoteViewScreen extends StatefulWidget {
  final String noteId;
  
  const NoteViewScreen({required this.noteId, Key? key}) : super(key: key);
  
  @override
  _NoteViewScreenState createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  late Future<NoteWithLinks> _noteFuture;
  Set<String> validNoteIds = {};
  
  @override
  void initState() {
    super.initState();
    _loadNote();
  }
  
  void _loadNote() {
    _noteFuture = apiService.getNoteWithLinks(widget.noteId);
    
    // When note loads, update our set of valid link targets
    _noteFuture.then((noteWithLinks) {
      setState(() {
        // Add IDs of all notes we have links to
        validNoteIds = {
          ...noteWithLinks.outgoingLinks.map((link) => link.targetId),
          ...noteWithLinks.incomingLinks.map((link) => link.sourceId)
        };
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Note Details')),
      body: FutureBuilder<NoteWithLinks>(
        future: _noteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final noteWithLinks = snapshot.data!;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noteWithLinks.note.title,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                buildNoteContent(
                  noteWithLinks.note.content,
                  (String noteId) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteViewScreen(noteId: noteId),
                    ),
                  ),
                  activeLinks: validNoteIds,
                ),
                // ... Rest of the UI
              ],
            ),
          );
        },
      ),
    );
  }
}
```

## Key Benefits of This Approach

1. **Data Integrity**: When a note is deleted, all links to and from that note are automatically deleted as well, preventing orphaned links.

2. **Performance**: No need to scan all notes to find links - direct database lookups provide efficient access to link relationships.

3. **Rich Metadata**: Each link can store additional information like link text, which can be different from the target note's title.

4. **Bi-directional Navigation**: Easy access to both outgoing links and backlinks through dedicated queries.

5. **UUID for all entities**: Both Notes and NoteLinks use UUIDs as primary keys, providing consistency and better security.

6. **Graceful handling of invalid links**: The backend silently skips invalid links rather than returning errors, and the frontend visually indicates broken links.

7. **Content Independence**: The actual content can be displayed with or without the link syntax, providing flexibility in UI rendering.

8. **Improved User Experience**: Broken links are visually indicated, and users are informed when attempting to interact with invalid links.

## Implementation Plan

1. **Database Schema**: Update the database schema to include the NoteLink table.

2. **Backend API**: Implement the enhanced endpoints for creating, retrieving, and managing links.

3. **Frontend Models**: Create the necessary data models to represent notes with links.

4. **UI Components**: 
   - Add link rendering in note view
   - Add link creation in note editor
   - Create link management UI sections

5. **Testing**: Ensure proper data integrity during note creation, updates, and deletion.