import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class RSSScreen extends StatefulWidget {
  @override
  State<RSSScreen> createState() => _RSSScreenState();
}

class _RSSScreenState extends State<RSSScreen> {
  void _showAddFeedDialog(BuildContext context, MyAppState appState) {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add RSS Feed', style: TextStyle(fontFamily: 'Serif')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
                style: TextStyle(fontFamily: 'Serif'),
              ),
              TextField(
                controller: urlController,
                decoration: InputDecoration(labelText: 'Feed URL'),
                style: TextStyle(fontFamily: 'Serif'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(fontFamily: 'Serif')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (urlController.text.trim().isNotEmpty && titleController.text.trim().isNotEmpty) {
                  await appState.addRSSFeed(urlController.text.trim(), titleController.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add', style: TextStyle(fontFamily: 'Serif')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final feeds = appState.rssFeeds;
    final feedsLoading = appState.feedsLoading;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.download),
                tooltip: 'Download feeds',
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.upload_file),
                tooltip: 'Import feeds',
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.add),
                tooltip: 'Add RSS feed',
                onPressed: () => _showAddFeedDialog(context, appState),
              ),
              SizedBox(width: 16),
            ],
          ),
        ),
      ),
      body: feedsLoading
          ? Center(child: CircularProgressIndicator())
          : feeds.isEmpty
              ? Center(child: Text('No RSS feeds yet.', style: TextStyle(fontFamily: 'Serif')))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: feeds.length,
                  itemBuilder: (context, index) {
                    final feed = feeds[index];
                    return Card(
                      color: Theme.of(context).colorScheme.surface,
                      margin: EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(feed.title, style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold)),
                        subtitle: Text(feed.url, style: TextStyle(fontFamily: 'Serif', fontSize: 13)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                          onPressed: () async {
                            await appState.removeRSSFeed(feed.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
