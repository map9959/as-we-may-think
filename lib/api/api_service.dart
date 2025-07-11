import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' show basename;

class ApiService {
  static const String baseUrl = 'http://localhost:8000'; // Change if needed

  // NOTES
  Future<List<dynamic>> getNotes() async {
    final response = await http.get(Uri.parse('$baseUrl/notes'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notes');
    }
  }

  Future<Map<String, dynamic>> addNote(String title, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'content': content}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add note');
    }
  }

  Future<void> deleteNote(String noteId) async {
    final response = await http.delete(Uri.parse('$baseUrl/notes/$noteId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete note');
    }
  }

  // SEARCH NOTES FOR LINKING
  Future<List<dynamic>> searchNotes(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notes/search?query=${Uri.encodeComponent(query)}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search notes');
    }
  }

  // FEEDS
  Future<List<dynamic>> getFeeds() async {
    final response = await http.get(Uri.parse('$baseUrl/feeds'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load feeds');
    }
  }

  Future<Map<String, dynamic>> addFeed(String url, String title) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feeds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url, 'title': title}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add feed');
    }
  }

  Future<void> deleteFeed(int feedId) async {
    final response = await http.delete(Uri.parse('$baseUrl/feeds/$feedId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete feed');
    }
  }

  // STORIES
  Future<List<dynamic>> getStories() async {
    final response = await http.get(Uri.parse('$baseUrl/stories'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception('Failed to load stories');
    }
  }

  // LLM ASSISTANT
  Future<Map<String, dynamic>> askLLM(String query, {int maxTokens = 64}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/llm/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'max_tokens': maxTokens,
        }),
      );
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get LLM response: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'answer': 'Error: Unable to get response from LLM assistant. $e',
        'sources': [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getLLMModels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/llm/models'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((model) => Map<String, dynamic>.from(model)).toList();
      } else {
        throw Exception('Failed to get models: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting LLM models: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> uploadLLMModel(String filePath, String modelName) async {
    try {
      final file = File(filePath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/llm/models/upload'));
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: basename(filePath),
        ),
      );
      
      request.fields['model_name'] = modelName;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to upload model: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading LLM model: $e');
      return {'message': 'Error: Failed to upload model - $e'};
    }
  }

  Future<Map<String, dynamic>> activateLLMModel(String modelName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/llm/models/activate/$modelName'),
      );
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to activate model: ${response.statusCode}');
      }
    } catch (e) {
      print('Error activating LLM model: $e');
      return {'message': 'Error: Failed to activate model - $e'};
    }
  }

  Future<Map<String, dynamic>> deleteLLMModel(String modelName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/llm/models/$modelName'),
      );
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to delete model: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting LLM model: $e');
      return {'message': 'Error: Failed to delete model - $e'};
    }
  }
}
