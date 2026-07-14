import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// 远程模式配置（REQ-API-002 远程模式安全）。
///
/// - 运行模式（local/remote）与 baseUrl：非敏感，存 SharedPreferences。
/// - API 密钥：敏感，存系统密钥库（flutter_secure_storage → Android Keystore / iOS Keychain），
///   绝不写入明文日志。
///
/// 默认模式为本地推理，部署远程兜底时需在此切换并填写 baseUrl 与密钥。
class RemoteSettings {
  static const String _kMode = 'mode';
  static const String _kBaseUrl = 'remote_base_url';
  static const String _kApiKey = 'remote_api_key'; // 仅存于系统密钥库

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // 使用 Android 加密 SharedPreferences（密钥库支撑）
    ),
  );

  /// 当前运行模式：'local' | 'remote'。
  static Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMode) ?? ApiConfig.mode;
  }

  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode == 'remote' ? 'remote' : 'local');
  }

  /// 远程 API baseUrl（非敏感）。
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? ApiConfig.baseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_kBaseUrl);
    } else {
      await prefs.setString(_kBaseUrl, trimmed);
    }
  }

  /// 远程 API 密钥（敏感）：仅从系统密钥库读取，禁止打印到日志。
  static Future<String> getApiKey() async {
    try {
      return await _secure.read(key: _kApiKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 写入/删除密钥：空字符串表示清除。
  static Future<void> setApiKey(String key) async {
    try {
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(key: _kApiKey);
      } else {
        await _secure.write(key: _kApiKey, value: trimmed);
      }
    } catch (_) {
      // 密钥库不可用时静默失败，不阻断其它设置保存。
    }
  }
}
