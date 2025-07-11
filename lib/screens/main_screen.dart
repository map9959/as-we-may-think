import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

class MainScreen extends StatefulWidget {
  final bool connectToWorld;

  MainScreen({super.key, required this.connectToWorld});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isAnimating = false;
  String _animatingText = '';
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  final ScrollController _scrollController = ScrollController();
  int? _hoveredStoryIdx;

  Ticker? _scrollTicker;
  late AnimationController _scrollSpeedController;
  late Animation<double> _scrollSpeedAnim;
  double _baseScrollSpeed = 0.7;

  List<_Story> _stories = [];
  bool _storiesLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -2.5),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _scrollSpeedController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _scrollSpeedAnim = Tween<double>(begin: _baseScrollSpeed, end: _baseScrollSpeed).animate(CurvedAnimation(
      parent: _scrollSpeedController,
      curve: Curves.easeInOut,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() {
      _storiesLoading = true;
    });
    final appState = context.read<MyAppState>();
    final stories = await fetchStoriesFromApi(appState);
    setState(() {
      _stories = [...stories, ...stories]; // duplicate for seamless looping
      _storiesLoading = false;
    });
  }

  void _setScrollSpeed(double target) {
    _scrollSpeedController.stop();
    _scrollSpeedAnim = Tween<double>(
      begin: _scrollSpeedAnim.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _scrollSpeedController,
      curve: Curves.easeInOut,
    ));
    _scrollSpeedController.forward(from: 0);
  }

  void _startAutoScroll() {
    if (_scrollTicker != null) {
      _scrollTicker!.dispose();
      _scrollTicker = null;
    }
    _scrollTicker = createTicker((elapsed) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      final double itemWidth = 140 + 24;
      final rssFeeds = context.read<MyAppState>().rssFeeds;
      final int baseCount = (rssFeeds.isEmpty ? 3 * 10 : rssFeeds.length * 10);
      final double loopLength = baseCount * itemWidth;
      if (max == 0) return;
      double speed = _scrollSpeedAnim.value;
      double next = current + speed;
      if (next >= max) {
        _scrollController.jumpTo(next - loopLength);
      } else {
        _scrollController.jumpTo(next);
      }
    });
    _scrollTicker!.start();
  }

  @override
  void dispose() {
    _scrollTicker?.dispose();
    _scrollSpeedController.dispose();
    _controller.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) async {
    if (value.trim().isEmpty) return;
    String initialTitle = value.trim().split('\n').first;
    String initialContent = value;
    TextEditingController titleController = TextEditingController(text: initialTitle);
    TextEditingController contentController = TextEditingController(text: initialContent);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 20),
                    decoration: InputDecoration(
                      hintText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.background,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  SizedBox(height: 18),
                  TextField(
                    controller: contentController,
                    style: TextStyle(fontFamily: 'Serif', fontSize: 16),
                    minLines: 6,
                    maxLines: 16,
                    decoration: InputDecoration(
                      hintText: 'Write your note...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.background,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel', style: TextStyle(fontFamily: 'Serif')),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          String title = titleController.text.trim();
                          String content = contentController.text.trim();
                          if (title.isNotEmpty && content.isNotEmpty) {
                            await Provider.of<MyAppState>(context, listen: false).addNote(title, content);
                          }
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Save', style: TextStyle(fontFamily: 'Serif')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    setState(() {
      _controller.clear();
    });
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (!(event.isShiftPressed)) {
        _onSubmitted(_controller.text);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final double itemWidth = 140 + 24; // width + separator
    final double loopLength = (_stories.length ~/ 2) * itemWidth;
    return Stack(
      children: [
        if (widget.connectToWorld)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MouseRegion(
              onEnter: (_) {
                setState(() {
                  _setScrollSpeed(0.0);
                });
              },
              onExit: (_) {
                setState(() {
                  _setScrollSpeed(_baseScrollSpeed);
                  _hoveredStoryIdx = null;
                });
              },
              child: SizedBox(
                height: 180,
                child: _storiesLoading
                    ? Center(child: CircularProgressIndicator())
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_scrollController.hasClients && _scrollController.offset >= loopLength) {
                            _scrollController.jumpTo(_scrollController.offset - loopLength);
                          }
                          return false;
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          itemCount: _stories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 24),
                          itemBuilder: (context, idx) {
                            final story = _stories[idx];
                            final isHovered = _hoveredStoryIdx == idx;
                            return MouseRegion(
                              onEnter: (_) => setState(() => _hoveredStoryIdx = idx),
                              onExit: (_) => setState(() => _hoveredStoryIdx = null),
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(story.title, style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold)),
                                      content: Text('Feed: ' + story.feedTitle + '\n\n' + story.content, style: TextStyle(fontFamily: 'Serif')),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('Close', style: TextStyle(fontFamily: 'Serif')),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 180),
                                      curve: Curves.easeInOut,
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.article, color: Colors.brown[400], size: 28),
                                            SizedBox(height: 12),
                                            Text(
                                              story.title,
                                              style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 15),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              story.feedTitle,
                                              style: TextStyle(fontFamily: 'Serif', fontSize: 12, color: Colors.brown[300]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedOpacity(
                                      opacity: isHovered ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 180),
                                      curve: Curves.easeInOut,
                                      child: Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.13),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        if (_isAnimating)
          Center(
            child: SlideTransition(
              position: _offsetAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    _animatingText,
                    style: TextStyle(fontFamily: 'Serif', fontSize: 22),
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), // more bottom padding
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                _onKey(FocusNode(), event);
              },
              child: TextField(
                controller: _controller,
                enabled: !_isAnimating,
                decoration: InputDecoration(
                  hintText: 'Type your thought...',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                style: TextStyle(fontFamily: 'Serif', fontSize: 18),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (val) {}, // handled by RawKeyboardListener
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Story {
  final String title;
  final String feedTitle;
  final String content;
  final String? link;
  final DateTime? published;
  _Story({required this.title, required this.feedTitle, required this.content, this.link, this.published});
}

Future<List<_Story>> fetchStoriesFromApi(MyAppState appState) async {
  final api = appState.apiService;
  final items = await api.getStories();
  return items.map<_Story>((item) {
    DateTime? published;
    if (item['published'] != null) {
      try {
        published = DateTime.parse(item['published']);
      } catch (_) {
        published = null;
      }
    }
    return _Story(
      title: item['title'] ?? '',
      feedTitle: item['feed_title'] ?? '',
      content: item['summary'] ?? '',
      link: item['link'],
      published: published,
    );
  }).toList();
}
