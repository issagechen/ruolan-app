import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class RuolanApp extends StatelessWidget {
  const RuolanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '若澜',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5E3C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF7F4),
      ),
      home: const HomeScreen(),
    );
  }
}
