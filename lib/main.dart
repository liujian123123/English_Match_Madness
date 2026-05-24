import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatchMadnessApp());
}

class MatchMadnessApp extends StatelessWidget {
  const MatchMadnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Madness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              ),
      home: const HomeScreen(),
    );
  }
}