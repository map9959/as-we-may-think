import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/rss_screen.dart';
import 'screens/llm_assistant_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'As We May Think',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Serif',
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: const Color(0xFFBCA77B),
            onPrimary: Colors.brown[900]!,
            secondary: const Color(0xFFD7C9A7),
            onSecondary: Colors.brown[800]!,
            error: Colors.red,
            onError: Colors.white,
            background: const Color(0xFFF2E9D0),
            onBackground: Colors.brown[900]!,
            surface: const Color(0xFFF2E9D0),
            onSurface: Colors.brown[900]!,
          ),
        ),
        home: MainScaffold(),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int selectedIndex = 0;
  bool sidebarOpen = false;
  bool connectToWorld = false;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      MainScreen(connectToWorld: connectToWorld),
      NotesScreen(),
      RSSScreen(),
      const LLMAssistantScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            setState(() {
              sidebarOpen = !sidebarOpen;
            });
          },
        ),
        actions: [
          Row(
            children: [
              Text('Connect to outside world', style: TextStyle(fontFamily: 'Serif')),
              Switch(
                value: connectToWorld,
                onChanged: (val) {
                  setState(() {
                    connectToWorld = val;
                  });
                },
              ),
              SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (sidebarOpen)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  selectedIndex = idx;
                  sidebarOpen = false;
                });
              },
              extended: true,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Main'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.note),
                  label: Text('Notes'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.rss_feed),
                  label: Text('RSS'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.smart_toy),
                  label: Text('LLM Assistant'),
                ),
              ],
            ),
          Expanded(child: screens[selectedIndex]),
        ],
      ),
    );
  }
}
