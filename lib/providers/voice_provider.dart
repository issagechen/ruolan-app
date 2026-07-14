import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';

enum CallState { idle, listening, thinking, speaking }

class VoiceProvider extends ChangeNotifier {
  final TtsService _tts = TtsService();
  final SttService _stt = SttService();
  bool _isSpeakerOn = true;
  bool _isInCallMode = false;
  CallState _callState = CallState.idle;
  String _callStatusText = '';

  TtsService get tts => _tts;
  SttService get stt => _stt;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isInCallMode => _isInCallMode;
  CallState get callState => _callState;
  String get callStatusText => _callStatusText;

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _tts.setEnabled(_isSpeakerOn);
    notifyListeners();
  }

  void enterCallMode() {
    _isInCallMode = true;
    _callState = CallState.idle;
    _callStatusText = '';
    notifyListeners();
  }

  void exitCallMode() {
    _isInCallMode = false;
    _callState = CallState.idle;
    _callStatusText = '';
    _stt.stop();
    _tts.stop();
    notifyListeners();
  }

  void setCallState(CallState state, {String? statusText}) {
    _callState = state;
    if (statusText != null) _callStatusText = statusText;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  /// Speak and return when speech finishes (for call mode)
  Future<void> speakAndWait(String text) async {
    await _tts.speakAndWait(text);
  }

  Future<String?> listenOnce() async {
    return await _stt.listenOnce();
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }
}
