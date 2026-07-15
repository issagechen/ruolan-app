import '../theme/ruolan_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/inference_settings.dart';
import '../config/remote_settings.dart';
import '../services/model_settings.dart';
import '../models/model_info.dart';
import '../services/llm_service.dart';
import '../providers/theme_provider.dart';

/// 关于与诊断页（REQ-SET-002）：展示应用版本、运行模式、当前模型、推理参数、
/// 外观主题与基础诊断信息，便于排查问题与汇报环境。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _appVersion = '1.0.0 (build 1)';

  bool _loading = true;
  String _mode = 'local';
  ModelInfo? _selectedModel;
  bool _modelMissing = false;
  late InferenceSettings _inference = const InferenceSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final mode = await RemoteSettings.getMode();
    final inference = await InferenceSettings.load();
    ModelInfo? selected;
    bool missing = false;
    try {
      final selectedPath = await ModelSettings.getSelectedPath();
      final maps = await LlmService.listModels();
      final models = maps.map((m) => ModelInfo.fromMap(m)).toList();
      if (selectedPath != null && selectedPath.isNotEmpty) {
        final hit = models.where((m) => m.path == selectedPath).firstOrNull;
        if (hit != null) {
          selected = hit;
        } else {
          missing = true;
        }
      }
    } catch (_) {
      // 模型扫描失败不阻断诊断页其余信息展示。
    }
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _inference = inference;
      _selectedModel = selected;
      _modelMissing = missing;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = RuolanColors.of(context);
    final themeMode = context.watch<ThemeProvider>().mode;
    final themeText = switch (themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('关于与诊断', style: TextStyle(color: colors.onSurfaceStrong)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primaryFg),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primaryFg))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 应用信息
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.primaryFg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 38),
                      ),
                      const SizedBox(height: 12),
                      Text('若澜 · AI 智能伴侣',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurfaceStrong)),
                      const SizedBox(height: 4),
                      Text('版本 $_appVersion', style: TextStyle(fontSize: 13, color: colors.onSurfaceMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _groupTitle(context, '运行模式'),
                _row(context, '当前模式',
                    _mode == 'remote' ? '远程 API' : '本地推理',
                    icon: Icons.cloud_outlined),
                _row(context, '默认模型标识', ApiConfig.model),
                const SizedBox(height: 16),
                _groupTitle(context, '当前模型'),
                if (_modelMissing)
                  _warn(context, '选中的模型文件未找到，请到「模型管理」重新选择或拷贝文件。')
                else if (_selectedModel != null)
                  _row(context, _selectedModel!.name, _selectedModel!.subtitle,
                      icon: Icons.model_training_outlined)
                else
                  _row(context, '未显式选择', '将使用目录中首个 .gguf',
                      icon: Icons.model_training_outlined, muted: true),
                _row(context, '模型目录', 'files/models 或 /sdcard/models', muted: true),
                const SizedBox(height: 16),
                _groupTitle(context, '推理参数'),
                _row(context, '上下文长度 (ctxSize)', '${_inference.ctxSize}'),
                _row(context, '单次最大生成 (maxTokens)', '${_inference.maxTokens}'),
                _row(context, '推理线程数 (threads)', '${_inference.threads}'),
                _row(context, '温度 (temperature)', _inference.temperature.toStringAsFixed(2)),
                _row(context, 'Top-P', _inference.topP.toStringAsFixed(2)),
                const SizedBox(height: 16),
                _groupTitle(context, '外观主题'),
                _row(context, '主题模式', themeText, icon: Icons.brightness_4_outlined),
                const SizedBox(height: 16),
                _groupTitle(context, '诊断提示'),
                _info(context,
                    '若对话无响应：检查模型是否已拷贝到模型目录、设备剩余存储与内存是否充足。\n'
                    '若语音识别无效：确认已授予麦克风权限，且设备已安装离线语音识别服务。\n'
                    '远程模式异常：核对 Base URL 与密钥（密钥仅存于系统密钥库）。'),
              ],
            ),
    );
  }

  Widget _groupTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RuolanColors.of(context).primaryFg)),
      );

  Widget _row(BuildContext context, String label, String value,
      {IconData? icon, bool muted = false}) {
    final colors = RuolanColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colors.primaryFg),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: colors.onSurface)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: muted ? colors.onSurfaceMuted : colors.onSurfaceStrong,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warn(BuildContext context, String text) {
    final colors = RuolanColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.errorBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.errorText, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: colors.errorText))),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String text) {
    final colors = RuolanColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: colors.onSurface, height: 1.5)),
    );
  }
}
