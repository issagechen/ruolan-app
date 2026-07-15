import '../theme/ruolan_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../models/agent_profile.dart';
import '../config/inference_settings.dart';
import '../widgets/settings/settings_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RuolanColors.of(context).background,
      appBar: AppBar(
        title: Text('智能体设置', style: TextStyle(color: RuolanColors.of(context).onSurfaceStrong)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: RuolanColors.of(context).primaryFg),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return Column(
            children: [
              _RoleManagerBar(settings: settings),
              const _ThemeSelector(),
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
                      SnackBar(
                        content: const Text('设置已保存，对话已重置'),
                        backgroundColor: RuolanColors.of(context).primaryFg,
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
      decoration: BoxDecoration(
        color: RuolanColors.of(context).chipBg,
        border: Border(bottom: BorderSide(color: RuolanColors.of(context).border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RuolanColors.of(context).onSurfaceStrong)),
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
                          color: active ? RuolanColors.of(context).primaryFg : RuolanColors.of(context).surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? RuolanColors.of(context).primaryFg : RuolanColors.of(context).border,
                          ),
                        ),
                        child: Text(p.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: active ? Colors.white : RuolanColors.of(context).primaryFg,
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
                      color: RuolanColors.of(context).surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: RuolanColors.of(context).primaryFg),
                    ),
                    child: Icon(Icons.add, size: 16, color: RuolanColors.of(context).primaryFg),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('点击切换角色 · 长按删除（仅 1 个时不可删）',
              style: TextStyle(fontSize: 11, color: RuolanColors.of(context).onSurfaceMuted)),
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

/// 外观主题切换：跟随系统 / 浅色 / 深色（REQ-UX-001）。
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('外观',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: RuolanColors.of(context).onSurfaceStrong)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            selected: {theme.mode},
            onSelectionChanged: (set) => theme.setMode(set.first),
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(Icons.brightness_auto)),
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode)),
            ],
          ),
        ],
      ),
    );
  }
}
