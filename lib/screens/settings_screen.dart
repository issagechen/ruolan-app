import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';
import '../models/agent_profile.dart';
import '../config/inference_settings.dart';
import '../widgets/settings/settings_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      appBar: AppBar(
        title: const Text('智能体设置', style: TextStyle(color: Color(0xFF5C3D2E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8B5E3C)),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return Column(
            children: [
              _RoleManagerBar(settings: settings),
              Expanded(
                child: SettingsForm(
                  // 按激活角色 id 重建表单，切换角色时即时载入对应配置。
                  key: ValueKey(settings.activeId),
                  initialProfile: settings.profile,
                  initialInference: settings.inference,
                  onSave: (AgentProfile profile) {
                    settings.updateActive(profile);
                    context.read<ChatProvider>().clearChat();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('设置已保存，对话已重置'),
                        backgroundColor: Color(0xFF8B5E3C),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  onSaveInference: (InferenceSettings inference) {
                    settings.saveInference(inference);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 角色管理条：点击切换、长按删除、加号新建（多角色 AVT-003）。
class _RoleManagerBar extends StatelessWidget {
  final SettingsProvider settings;
  const _RoleManagerBar({required this.settings});

  @override
  Widget build(BuildContext context) {
    final profiles = settings.profiles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF3E9E1),
        border: Border(bottom: BorderSide(color: Color(0xFFE0D5CC), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('角色',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5C3D2E))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...profiles.map((p) {
                  final active = p.id == settings.activeId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => settings.setActive(p.id),
                      onLongPress: () => _confirmDelete(context, p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF8B5E3C) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? const Color(0xFF8B5E3C) : const Color(0xFFE0D5CC),
                          ),
                        ),
                        child: Text(p.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: active ? Colors.white : const Color(0xFF8B5E3C),
                            )),
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => settings.createProfile(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFC9A88C)),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Color(0xFF8B5E3C)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('点击切换角色 · 长按删除（仅 1 个时不可删）',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AgentProfile p) {
    if (settings.profiles.length <= 1) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定删除「${p.name}」？该角色的配置将移除（对话历史不受影响）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              settings.deleteProfile(p.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
