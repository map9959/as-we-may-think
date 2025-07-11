import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../api/api_service.dart';

class LLMAssistantScreen extends StatefulWidget {
  const LLMAssistantScreen({Key? key}) : super(key: key);

  @override
  _LLMAssistantScreenState createState() => _LLMAssistantScreenState();
}

class _LLMAssistantScreenState extends State<LLMAssistantScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _queryController = TextEditingController();
  
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = false;
  String _assistantResponse = '';
  List<Map<String, dynamic>> _sources = [];
  
  @override
  void initState() {
    super.initState();
    _loadModels();
  }
  
  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final models = await _apiService.getLLMModels();
      setState(() {
        _models = models;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading models: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _uploadModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
      );
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        // Show dialog for model name
        final modelName = await showDialog<String>(
          context: context,
          builder: (context) => _ModelNameDialog(
            initialName: fileName.replaceAll('.gguf', ''),
          ),
        );
        
        if (modelName != null && modelName.isNotEmpty) {
          setState(() {
            _isLoading = true;
          });
          
          final response = await _apiService.uploadLLMModel(
            file.path,
            modelName,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Model uploaded')),
          );
          
          _loadModels();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading model: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _activateModel(String modelName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _apiService.activateLLMModel(modelName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Model activated successfully')),
      );
      _loadModels();
    } catch (e) {
      // Extract the detailed error message from the error response if available
      String errorMessage = 'Error activating model';
      
      if (e is Exception) {
        String errorText = e.toString();
        
        // Try to extract the detailed message from the HTTP error
        final detailMatch = RegExp(r'"detail":"([^"]+)"').firstMatch(errorText);
        if (detailMatch != null && detailMatch.groupCount >= 1) {
          errorMessage = detailMatch.group(1) ?? errorMessage;
        } else {
          errorMessage = '$errorMessage: $errorText';
        }
      }
      
      // Show error dialog with detailed message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Model Activation Failed'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteModel(String modelName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete "$modelName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final response = await _apiService.deleteLLMModel(modelName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Model deleted')),
        );
        _loadModels();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting model: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _askQuestion() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _assistantResponse = '';
      _sources = [];
    });
    
    try {
      final response = await _apiService.askLLM(query);
      setState(() {
        _assistantResponse = response['answer'] ?? 'No response received';
        _sources = List<Map<String, dynamic>>.from(response['sources'] ?? []);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting response: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModels,
            tooltip: 'Refresh models',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildModelsSection(),
              const Divider(),
              Expanded(
                child: _buildChatSection(),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadModel,
        tooltip: 'Upload model',
        child: const Icon(Icons.upload_file),
      ),
    );
  }
  
  Widget _buildModelsSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Available Models',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_models.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No LLM models available. Upload a GGUF model file to get started.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            SizedBox(
              height: 100, // Increased height from 80 to 100 pixels to avoid overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _models.length,
                itemBuilder: (context, index) {
                  final model = _models[index];
                  final isActive = model['is_active'] ?? false;
                  
                  return Card(
                    color: isActive ? Colors.blue.shade100 : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, // Added to better center content vertically
                        children: [
                          Text(
                            model['name'] ?? 'Unknown model',
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis, // Added to handle long model names
                          ),
                          const SizedBox(height: 4), // Small spacing between text and buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => _activateModel(model['name']),
                                  tooltip: 'Activate model',
                                  iconSize: 20,
                                  padding: const EdgeInsets.all(4), // Reduce padding to save space
                                  constraints: const BoxConstraints(), // Remove default minimum size constraints
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteModel(model['name']),
                                tooltip: 'Delete model',
                                iconSize: 20,
                                padding: const EdgeInsets.all(4), // Reduce padding to save space
                                constraints: const BoxConstraints(), // Remove default minimum size constraints
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildChatSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask a Question',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your question...',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _askQuestion(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _askQuestion,
                tooltip: 'Send question',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_assistantResponse.isNotEmpty) ...[
            Text(
              'Response:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_assistantResponse),
                    ),
                    if (_sources.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Sources:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ..._sources.map((source) => _buildSourceCard(source)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSourceCard(Map<String, dynamic> source) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source['title'] ?? 'Untitled',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              source['content'] ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}

class _ModelNameDialog extends StatefulWidget {
  final String initialName;
  
  const _ModelNameDialog({
    Key? key,
    required this.initialName,
  }) : super(key: key);

  @override
  _ModelNameDialogState createState() => _ModelNameDialogState();
}

class _ModelNameDialogState extends State<_ModelNameDialog> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Model Name'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter a name for the model',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}