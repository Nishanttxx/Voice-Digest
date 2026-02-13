import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_digest/providers/theme_provider.dart';
import 'package:voice_digest/screens/history_screen.dart';
import 'package:voice_digest/screens/home_screen.dart';
import 'package:voice_digest/screens/settings_screen.dart';
import 'package:voice_digest/services/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final isarService = IsarService();
  runApp(ProviderScope(child: VoiceDigestApp(isarService: isarService)));
}

class VoiceDigestApp extends ConsumerWidget {
  final IsarService isarService;
  const VoiceDigestApp({super.key, required this.isarService});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Voice Digest',
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFf0f0f0),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.transparent, // For the gradient background
      ),
      home: NavHostScreen(isarService: isarService),
    );
  }
}

class NavHostScreen extends ConsumerStatefulWidget {
  final IsarService isarService;
  const NavHostScreen({super.key, required this.isarService});

  @override
  ConsumerState<NavHostScreen> createState() => _NavHostScreenState();
}

class _NavHostScreenState extends ConsumerState<NavHostScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      HomeScreen(isarService: widget.isarService),
      HistoryScreen(isarService: widget.isarService),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      decoration: themeMode == ThemeMode.dark
          ? const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : null,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: themeMode == ThemeMode.dark ? Colors.black.withOpacity(0.3) : null,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
