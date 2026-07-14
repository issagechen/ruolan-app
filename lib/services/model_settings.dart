import 'package:shared_preferences/shared_preferences.dart';

/// 模型选择持久化（INF-006 模型管理）。
///
/// 保存用户在设置中选中的模型文件路径；为空时由 ChatService 回退到
/// `LlmService.getDefaultModelPath()`（原生搜索路径中的首个 model.gguf）。
class ModelSettings {
  static const String _key = 'selected_model_path';

  /// 读取选中模型路径；未选择返回 null。
  static Future<String?> getSelectedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 写入选中模型路径。
  static Future<void> setSelectedPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}
