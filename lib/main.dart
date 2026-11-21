import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FocusGuardApp());
}

class FocusGuardApp extends StatefulWidget {
  const FocusGuardApp({super.key});

  @override
  State<FocusGuardApp> createState() => _FocusGuardAppState();
}

class _FocusGuardAppState extends State<FocusGuardApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusGuard',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Color(0xFF161616),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}
