import 'dart:async';
import 'package:flutter/services.dart';

class SttService {
  static const MethodChannel _channel = MethodChannel('com.ruolan.stt');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('available') == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> listenOnce() async {
    try {
      return await _channel.invokeMethod('listen') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {}
}
