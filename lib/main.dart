import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/voice_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 不锁定方向：允许竖屏，由 HomeScreen 的响应式布局自适应（REQ-UX-002）。
  try { await StorageService.init(); } catch (_) {}

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()..load().catchError((_){})),
      ChangeNotifierProvider(create: (_) => VoiceProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()..loadHistory().catchError((_){})),
    ],
    child: const RuolanApp(),
  ));
}
