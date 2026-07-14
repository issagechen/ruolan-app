import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/voice_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try { await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); } catch (_) {}
  try { await StorageService.init(); } catch (_) {}

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()..load().catchError((_){})),
      ChangeNotifierProvider(create: (_) => VoiceProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()..loadHistory().catchError((_){})),
    ],
    child: const RuolanApp(),
  ));
}
