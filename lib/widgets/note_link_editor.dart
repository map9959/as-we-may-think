import 'package:flutter/material.dart';
import 'dart:async';
import '../api/api_service.dart';

class NoteLinkEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const NoteLinkEditor({
    Key? key,
    required this.controller,
    required this.focusNode,
  }) : super(key: key);

  @override
  State<NoteLinkEditor> createState() => _NoteLinkEditorState();
}

class _NoteLinkEditorState extends State<NoteLinkEditor> {
  final ApiService _apiService = ApiService();
  Timer? _debounce;
  
  // Regular expressions for link detection
  final RegExp _basicLinkPattern = RegExp(r'\[([^\]]+)\]\($');
  final RegExp _noteLinkPattern = RegExp(r'\[([^\]]+)\]\(note:([a-zA-Z0-9-]*)$');
  
  // For manual link insertion
  final GlobalKey _editorKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
  
  void _onTextChanged() {
    if (widget.controller.selection.baseOffset < 0) return;
    
    // Check if we're typing a link
    _checkForLinkTyping();
  }
  
  void _checkForLinkTyping() {
    if (!widget.focusNode.hasFocus) return;
    
    final cursorPosition = widget.controller.selection.baseOffset;
    if (cursorPosition <= 0 || cursorPosition > widget.controller.text.length) {
      return;
    }
    
    // Look for link patterns before the cursor
    final textBeforeCursor = widget.controller.text.substring(0, cursorPosition);
    
    // Check for [text]( pattern
    final basicMatch = _basicLinkPattern.firstMatch(textBeforeCursor);
    
    if (basicMatch != null) {
      final linkText = basicMatch.group(1) ?? '';
      _showNoteSelector(linkText, '');
      return;
    }
    
    // Check if we're in the middle of typing a note ID
    final noteIdMatch = _noteLinkPattern.firstMatch(textBeforeCursor);
    if (noteIdMatch != null) {
      final linkText = noteIdMatch.group(1) ?? '';
      final searchText = noteIdMatch.group(2) ?? '';
      _showNoteSelector(linkText, searchText);
      return;
    }
  }
  
  void _showNoteSelector(String linkText, String searchQuery) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      // Get the render box of the editor
      final RenderBox? renderBox = _editorKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      // Calculate position for the popup
      final cursorPosition = widget.controller.selection.baseOffset;
      final textBeforeCursor = widget.controller.text.substring(0, cursorPosition);
      final lineBreaks = '\n'.allMatches(textBeforeCursor).length;
      
      // Show a popup menu at the cursor position
      final notes = await _apiService.searchNotes(searchQuery);
      
      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notes found')),
        );
        return;
      }
      
      // Show a simple menu with note options
      final result = await showMenu<Map<String, dynamic>>(
        context: context,
        position: RelativeRect.fromLTRB(100, 100 + (lineBreaks * 20), 100, 100),
        items: [
          ...notes.map((note) => PopupMenuItem<Map<String, dynamic>>(
            value: note,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note['title'] ?? 'Untitled', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Created: ${note['created_at']?.toString().substring(0, 10) ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 12)),
              ],
            ),
          )),
        ],
      );
      
      if (result != null) {
        _insertNoteLink(linkText, result['id']);
      }
    });
  }
  
  void _insertNoteLink(String linkText, String noteId) {
    // Get the current text and cursor position
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    
    // Find the position of the opening bracket before the cursor
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastOpenBracket = textBeforeCursor.lastIndexOf('[');
    
    if (lastOpenBracket >= 0) {
      // Calculate the range to replace
      final startPos = lastOpenBracket;
      final endPos = selection.baseOffset;
      
      // Create the replacement text
      final replacement = '[$linkText](note:$noteId)';
      
      // Create the updated text
      final updatedText = text.replaceRange(startPos, endPos, replacement);
      final newCursorPosition = startPos + replacement.length;
      
      // Update the text field
      widget.controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }
    
    // Restore focus to the text field
    widget.focusNode.requestFocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _editorKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      maxLines: null,
      decoration: InputDecoration(
        hintText: 'Note content...',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.link),
          tooltip: 'Insert link to note',
          onPressed: () async {
            // Show a simple dialog to manually insert a link
            final notes = await _apiService.searchNotes('');
            if (notes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No notes found')),
              );
              return;
            }
            
            // Get current selection as link text
            String linkText = '';
            final selection = widget.controller.selection;
            if (selection.isValid && !selection.isCollapsed) {
              linkText = widget.controller.text.substring(
                selection.start, selection.end);
            }
            
            // Show a simple menu with note options
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Select a note to link'),
                children: [
                  ...notes.map((note) => SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context, note);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note['title'] ?? 'Untitled', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Created: ${note['created_at']?.toString().substring(0, 10) ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
                ],
              ),
            );
            
            if (result != null) {
              // If no text is selected, use the note title as link text
              if (linkText.isEmpty) {
                linkText = result['title'] ?? 'Untitled';
              }
              
              // Insert the link at the current cursor position
              final currentText = widget.controller.text;
              final currentPosition = widget.controller.selection.baseOffset;
              final replacement = '[$linkText](note:${result['id']})';
              
              if (selection.isValid && !selection.isCollapsed) {
                // Replace selected text with link
                final newText = currentText.replaceRange(
                  selection.start, selection.end, replacement);
                widget.controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: selection.start + replacement.length),
                );
              } else {
                // Insert link at cursor position
                final newText = currentText.replaceRange(
                  currentPosition, currentPosition, replacement);
                widget.controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: currentPosition + replacement.length),
                );
              }
            }
          },
        ),
      ),
    );
  }
}