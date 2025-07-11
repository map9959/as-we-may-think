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
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  bool _isLoading = false;
  int _cursorPosition = 0;
  String _linkText = '';
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }
  
  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _overlayController.hide();
    }
  }
  
  void _onTextChanged() {
    setState(() {
      _cursorPosition = widget.controller.selection.baseOffset;
    });
    
    // Check if we're typing a link
    _checkForLinkTyping();
  }
  
  void _checkForLinkTyping() {
    if (_cursorPosition <= 0 || _cursorPosition > widget.controller.text.length) {
      _overlayController.hide();
      return;
    }
    
    // Look for [text]( pattern before the cursor
    final textBeforeCursor = widget.controller.text.substring(0, _cursorPosition);
    final match = RegExp(r'\[(.+?)\]\($').firstMatch(textBeforeCursor);
    
    if (match != null) {
      _linkText = match.group(1) ?? '';
      _searchNotes('');  // Show all notes initially
      _overlayController.show();
    } else {
      // Check if we're in the middle of typing a note ID
      final noteIdMatch = RegExp(r'\[(.+?)\]\(note:([a-zA-Z0-9-]*)$').firstMatch(textBeforeCursor);
      if (noteIdMatch != null) {
        _linkText = noteIdMatch.group(1) ?? '';
        final searchText = noteIdMatch.group(2) ?? '';
        _searchNotes(searchText);
        _overlayController.show();
      } else {
        _overlayController.hide();
      }
    }
  }
  
  void _searchNotes(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final results = await _apiService.searchNotes(query);
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    });
  }
  
  void _selectNote(dynamic note) {
    final noteId = note['id'];
    final noteTitle = note['title'];
    
    // Get the current text and cursor position
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    
    // Find the position of the opening bracket before the cursor
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastOpenBracket = textBeforeCursor.lastIndexOf('[');
    
    if (lastOpenBracket >= 0) {
      // Find where we are in the link pattern
      final linkPattern = RegExp(r'\[(.+?)\]\(note:([a-zA-Z0-9-]*)$');
      final match = linkPattern.firstMatch(textBeforeCursor);
      
      if (match != null) {
        // We're already partially inside a note: link - replace it
        final startPos = lastOpenBracket;
        final newText = '[$_linkText](note:$noteId)';
        
        final updatedText = text.replaceRange(startPos, selection.baseOffset, newText);
        final newCursorPosition = startPos + newText.length;
        
        widget.controller.value = TextEditingValue(
          text: updatedText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
      } else {
        // We just have [text]( - complete it
        final startPos = textBeforeCursor.lastIndexOf('[');
        final currentLink = textBeforeCursor.substring(startPos);
        final replacement = '[$_linkText](note:$noteId)';
        
        final updatedText = text.replaceRange(startPos, selection.baseOffset, replacement);
        final newCursorPosition = startPos + replacement.length;
        
        widget.controller.value = TextEditingValue(
          text: updatedText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
      }
    }
    
    _overlayController.hide();
    widget.focusNode.requestFocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: 200,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _suggestions.isEmpty
                        ? ListTile(
                            title: Text(
                              'No notes found',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final note = _suggestions[index];
                              return ListTile(
                                title: Text(note['title']),
                                subtitle: Text(
                                  'Created: ${note['created_at']?.toString().substring(0, 10) ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _selectNote(note),
                              );
                            },
                          ),
              ),
            ),
          );
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Note content...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}