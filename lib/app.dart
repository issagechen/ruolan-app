import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/ruolan_colors.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

class RuolanApp extends StatelessWidget {
  const RuolanApp({super.key});

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RuolanColors.light.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: RuolanColors.light.background,
    appBarTheme: AppBarTheme(
      backgroundColor: RuolanColors.light.background,
      foregroundColor: RuolanColors.light.onSurfaceStrong,
      elevation: 0,
    ),
    extensions: const [RuolanColors.light],
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RuolanColors.dark.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: RuolanColors.dark.background,
    appBarTheme: AppBarTheme(
      backgroundColor: RuolanColors.dark.background,
      foregroundColor: RuolanColors.dark.onSurfaceStrong,
      elevation: 0,
    ),
    extensions: const [RuolanColors.dark],
  );

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: '若澜',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const HomeScreen(),
    );
  }
}
