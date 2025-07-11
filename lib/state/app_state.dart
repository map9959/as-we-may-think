import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:as_we_may_think/api/api_service.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime created;
  Note({required this.id, required this.title, required this.content, required this.created});
}

class RSSFeed {
  final int id;
  final String url;
  final String title;
  RSSFeed({required this.id, required this.url, required this.title});
}

class MyAppState extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  List<Note> notes = [];
  bool notesLoading = false;
  Future<void> loadNotes() async {
    notesLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getNotes();
      notes = data.map<Note>((n) => Note(
        id: n['id'],
        title: n['title'],
        content: n['content'],
        created: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
      )).toList();
    } catch (e) {
      // handle error
    }
    notesLoading = false;
    notifyListeners();
  }

  Future<void> addNote(String title, String content) async {
    try {
      final n = await _apiService.addNote(title, content);
      notes.insert(0, Note(
        id: n['id'],
        title: n['title'],
        content: n['content'],
        created: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
      ));
      notifyListeners();
    } catch (e) {
      // handle error
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _apiService.deleteNote(noteId);
      notes.removeWhere((note) => note.id == noteId);
      notifyListeners();
    } catch (e) {
      // handle error
    }
  }

  Future<void> updateNote(String noteId, String title, String content) async {
    // This is a client-side only update since we don't have a backend update endpoint yet
    try {
      final index = notes.indexWhere((note) => note.id == noteId);
      if (index != -1) {
        // Create a new note instance with updated content but same ID
        final updatedNote = Note(
          id: noteId,
          title: title,
          content: content,
          created: notes[index].created,
        );
        
        // Replace the old note with the updated one
        notes[index] = updatedNote;
        notifyListeners();
      }
    } catch (e) {
      // handle error
    }
  }

  Note? findNoteById(String id) {
    try {
      return notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  List<RSSFeed> rssFeeds = [];
  bool feedsLoading = false;
  Future<void> loadFeeds() async {
    feedsLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getFeeds();
      rssFeeds = data.map<RSSFeed>((f) => RSSFeed(
        id: f['id'],
        url: f['url'],
        title: f['title'] ?? '',
      )).toList();
    } catch (e) {
      // handle error
    }
    feedsLoading = false;
    notifyListeners();
  }

  Future<void> addRSSFeed(String url, String title) async {
    try {
      final f = await _apiService.addFeed(url, title);
      rssFeeds.add(RSSFeed(id: f['id'], url: f['url'], title: f['title'] ?? ''));
      notifyListeners();
    } catch (e) {
      // handle error
    }
  }

  Future<void> removeRSSFeed(int feedId) async {
    try {
      await _apiService.deleteFeed(feedId);
      rssFeeds.removeWhere((feed) => feed.id == feedId);
      notifyListeners();
    } catch (e) {
      // handle error
    }
  }

  MyAppState() {
    loadNotes();
    loadFeeds();
  }
}
