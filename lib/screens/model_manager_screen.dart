import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model_info.dart';
import '../services/llm_service.dart';
import '../services/model_settings.dart';
import '../providers/chat_provider.dart';

/// 模型管理界面（INF-006）：列出设备上的 GGUF 模型，显示大小/量化信息，
/// 支持在设置内切换并热重载；选中模型缺失时给出引导。
class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  List<ModelInfo> _models = [];
  String? _selectedPath;
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final maps = await LlmService.listModels();
    final models = maps.map((m) => ModelInfo.fromMap(m)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selected = await ModelSettings.getSelectedPath();
    if (mounted) {
      setState(() {
        _models = models;
        _selectedPath = selected;
        _loading = false;
      });
    }
  }

  Future<void> _select(ModelInfo model) async {
    if (_switching) return;
    setState(() => _switching = true);
    final ok = await context.read<ChatProvider>().switchModel(model.path);
    if (!mounted) return;
    setState(() {
      _switching = false;
      if (ok) _selectedPath = model.path;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '已切换模型：${model.name}，已热重载' : '切换失败：${model.name} 加载错误'),
      backgroundColor: ok ? const Color(0xFF8B5E3C) : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      appBar: AppBar(
        title: const Text('模型管理', style: TextStyle(color: Color(0xFF5C3D2E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8B5E3C)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新扫描',
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5E3C)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final selectedExists = _selectedPath != null &&
        _models.any((m) => m.path == _selectedPath);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('选择本地模型文件（.gguf）进行切换，切换后即时热重载，无需重启应用。',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B5E3C))),
        const SizedBox(height: 8),
        const Text('模型目录：应用内部 files/models 或 /sdcard/models',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        if (!selectedExists && _selectedPath != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEAEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('当前选中的模型文件未找到（可能已被移除）。请选择下方模型或拷贝文件到模型目录。',
              style: TextStyle(fontSize: 13, color: Colors.redAccent)),
          ),
        if (_models.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(children: [
              Icon(Icons.folder_open_outlined, size: 40, color: Color(0xFFC9A88C)),
              SizedBox(height: 12),
              Text('未找到任何模型文件', style: TextStyle(fontSize: 15, color: Color(0xFF5C3D2E))),
              SizedBox(height: 6),
              Text('请将 .gguf 模型拷贝到：\n应用内部 files/models 或 /sdcard/models',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
          )
        else
          ..._models.map((m) => _modelTile(m)),
        const SizedBox(height: 16),
        if (_switching) const Center(child: CircularProgressIndicator(color: Color(0xFF8B5E3C))),
      ],
    );
  }

  Widget _modelTile(ModelInfo m) {
    final isSelected = m.path == _selectedPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFE3D8) : const Color(0xFFF5F0EC),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF8B5E3C), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.description_outlined,
          color: isSelected ? const Color(0xFF8B5E3C) : const Color(0xFFC9A88C),
        ),
        title: Text(m.name, style: const TextStyle(fontSize: 15, color: Color(0xFF5C3D2E))),
        subtitle: Text(m.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: isSelected
            ? const Text('使用中', style: TextStyle(fontSize: 12, color: Color(0xFF8B5E3C)))
            : const Text('点击切换', style: TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: _switching ? null : () => _select(m),
      ),
    );
  }
}
