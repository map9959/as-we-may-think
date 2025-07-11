import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/link_text.dart';
import '../widgets/note_link_editor.dart';

class NotesScreen extends StatefulWidget {
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  int? expandedIndex;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Note> filteredNotes = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNotes(List<Note> notes) {
    setState(() {
      if (searchQuery.trim().isEmpty) {
        filteredNotes = notes;
      } else {
        final q = searchQuery.trim().toLowerCase();
        filteredNotes = notes.where((note) =>
          note.title.toLowerCase().contains(q) ||
          note.content.toLowerCase().contains(q)
        ).toList();
      }
      expandedIndex = null;
    });
  }

  void _handleNoteLinkTap(BuildContext context, String noteId) {
    final appState = Provider.of<MyAppState>(context, listen: false);
    final targetNote = appState.findNoteById(noteId);
    
    if (targetNote != null) {
      // Find the index of the target note in the filtered list
      final targetIndex = filteredNotes.indexWhere((note) => note.id == noteId);
      if (targetIndex != -1) {
        // Expand the target note
        setState(() {
          expandedIndex = targetIndex;
        });
        
        // Scroll to the target note with a slight delay to ensure the list has updated
        Future.delayed(Duration(milliseconds: 100), () {
          Scrollable.ensureVisible(
            context,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      } else {
        // Note exists but isn't in the filtered list (may be filtered out by search)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note "${targetNote.title}" found but not in current view'),
            action: SnackBarAction(
              label: 'Clear Search',
              onPressed: () {
                _searchController.clear();
                searchQuery = '';
                _filterNotes(appState.notes);
              },
            ),
          ),
        );
      }
    } else {
      // Note doesn't exist or was deleted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note not found (may have been deleted)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final notes = appState.notes;
    final notesLoading = appState.notesLoading;
    if (filteredNotes.isEmpty && searchQuery.isEmpty) {
      filteredNotes = notes;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            style: TextStyle(fontFamily: 'Serif', fontSize: 16),
            onSubmitted: (val) {
              searchQuery = val;
              _filterNotes(notes);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Note'),
              onPressed: () async {
                final result = await _showAddNoteDialog(context);
                if (result != null) {
                  final title = result['title']!.trim();
                  final content = result['content']!.trim();
                  if (title.isNotEmpty || content.isNotEmpty) {
                    await appState.addNote(title, content);
                    _filterNotes(appState.notes);
                  }
                }
              },
            ),
          ),
        ),
        Expanded(
          child: notesLoading
              ? Center(child: CircularProgressIndicator())
              : filteredNotes.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isEmpty ? 'No notes yet.' : 'No notes found.',
                        style: TextStyle(fontFamily: 'Serif'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        final isExpanded = expandedIndex == index;
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              if (isExpanded)
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() {
                                expandedIndex = isExpanded ? null : index;
                              });
                            },
                            child: AnimatedCrossFade(
                              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: Duration(milliseconds: 300),
                              firstChild: ListTile(
                                title: Text(note.title, style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  _formatDate(note.created),
                                  style: TextStyle(fontFamily: 'Serif', fontSize: 12, color: Colors.brown[400]),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.delete_outline),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        await appState.deleteNote(note.id);
                                        _filterNotes(appState.notes);
                                      },
                                    ),
                                    Icon(Icons.expand_more),
                                  ],
                                ),
                              ),
                              secondChild: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(note.title, style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit),
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final result = await _showEditNoteDialog(context, note);
                                            if (result != null) {
                                              final title = result['title']!.trim();
                                              final content = result['content']!.trim();
                                              if (title.isNotEmpty || content.isNotEmpty) {
                                                await appState.updateNote(note.id, title, content);
                                                _filterNotes(appState.notes);
                                              }
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.expand_less),
                                          onPressed: () {
                                            setState(() {
                                              expandedIndex = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    // Use LinkText widget instead of plain Text
                                    LinkText(
                                      text: note.content,
                                      style: TextStyle(fontFamily: 'Serif', fontSize: 16),
                                      onNoteLinkTap: (noteId) => _handleNoteLinkTap(context, noteId),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      _formatDate(note.created),
                                      style: TextStyle(fontFamily: 'Serif', fontSize: 12, color: Colors.brown[400]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<Map<String, String>?> _showAddNoteDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final contentFocusNode = FocusNode();
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Note', style: TextStyle(fontFamily: 'Serif')),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: NoteLinkEditor(
                  controller: contentController,
                  focusNode: contentFocusNode,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tip: To create a link to another note, type [text](',
                style: TextStyle(
                  fontFamily: 'Serif', 
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Serif')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'title': titleController.text,
                'content': contentController.text
              });
            },
            child: Text('Add', style: TextStyle(fontFamily: 'Serif')),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showEditNoteDialog(BuildContext context, Note note) async {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);
    final contentFocusNode = FocusNode();
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Note', style: TextStyle(fontFamily: 'Serif')),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: NoteLinkEditor(
                  controller: contentController,
                  focusNode: contentFocusNode,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tip: To create a link to another note, type [text](',
                style: TextStyle(
                  fontFamily: 'Serif', 
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Serif')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'title': titleController.text,
                'content': contentController.text
              });
            },
            child: Text('Save', style: TextStyle(fontFamily: 'Serif')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
