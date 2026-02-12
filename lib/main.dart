import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'managers/audio_manager.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  await SharedPreferences.getInstance();

  // Preload and verify all sounds
  await AudioManager().preloadAllSounds();

  runApp(const BedtimeStoriesApp());
}

class BedtimeStoriesApp extends StatefulWidget {
  const BedtimeStoriesApp({Key? key}) : super(key: key);

  @override
  State<BedtimeStoriesApp> createState() => _BedtimeStoriesAppState();
}

class _BedtimeStoriesAppState extends State<BedtimeStoriesApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bedtime Stories',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? _darkTheme : _lightTheme,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
    );
  }

  ThemeData get _lightTheme => ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'ComicNeue',
        scaffoldBackgroundColor: const Color(0xFFFFF8E7),
        brightness: Brightness.light,
      );

  ThemeData get _darkTheme => ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'ComicNeue',
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        brightness: Brightness.dark,
      );
}
