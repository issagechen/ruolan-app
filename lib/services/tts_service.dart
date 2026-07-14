import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isEnabled = true;
  bool _initFailed = false;

  bool get isEnabled => _isEnabled;

  Future<void> _safeInit() async {
    if (_initFailed) return;
    try {
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {
      _initFailed = true;
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    try {
      await _safeInit();
      if (_initFailed) return;
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  /// Speak and return a Future that completes when speech finishes.
  Future<void> speakAndWait(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    try {
      await _safeInit();
      if (_initFailed) return;
      await _flutterTts.stop();

      final completer = Completer<void>();
      // setCompletionHandler returns void, cannot await
      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });

      await _flutterTts.speak(text);
      return completer.future;
    } catch (_) {
      return;
    }
  }

  Future<void> stop() async {
    try { await _flutterTts.stop(); } catch (_) {}
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) stop();
  }
}
