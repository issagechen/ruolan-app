import '../../theme/ruolan_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voice_provider.dart';
import '../../services/stt_service.dart';
import '../../screens/settings_screen.dart';
import 'session_panel.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showSessionPanel(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.forum_outlined, color: RuolanColors.of(context).primaryFg, size: 24),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.menu, color: RuolanColors.of(context).primaryFg, size: 28),
            ),
          ),
          const Spacer(),
          // Call mode status text
          Consumer<VoiceProvider>(
            builder: (context, voice, _) {
              if (!voice.isInCallMode) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  voice.callStatusText,
                  style: TextStyle(
                    fontSize: 13,
                    color: RuolanColors.of(context).primaryFg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          // Phone button
          GestureDetector(
            onTap: () {
              final voice = context.read<VoiceProvider>();
              if (voice.isInCallMode) {
                voice.exitCallMode();
              } else {
                _confirmEnterCall(context, voice);
              }
            },
            child: Consumer<VoiceProvider>(
              builder: (context, voice, _) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: voice.isInCallMode
                      ? BoxDecoration(
                          color: RuolanColors.of(context).errorText.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        )
                      : null,
                  child: Icon(
                    voice.isInCallMode ? Icons.call_end : Icons.phone,
                    color: voice.isInCallMode ? Colors.red : RuolanColors.of(context).primaryFg,
                    size: 24,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.read<VoiceProvider>().toggleSpeaker();
            },
            child: Consumer<VoiceProvider>(
              builder: (context, voice, _) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    voice.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    color: voice.isSpeakerOn ? RuolanColors.of(context).primaryFg : RuolanColors.of(context).onSurfaceMuted,
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 进入语音通话前的麦克风权限说明（REQ-VOC-003）。
  /// 说明麦克风用途与系统授权路径；若设备语音识别不可用额外警示。
  /// 每次发起通话都会弹出，满足「首次说明」与「拒绝后再次触发」。
  Future<void> _confirmEnterCall(BuildContext context, VoiceProvider voice) async {
    final colors = RuolanColors.of(context);
    final available = await SttService().isAvailable();
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic, color: colors.primaryFg),
            const SizedBox(width: 8),
            Text('语音通话需要麦克风', style: TextStyle(color: colors.onSurfaceStrong)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('若澜的语音通话会使用设备麦克风进行语音识别。',
                style: TextStyle(color: colors.onSurface)),
            const SizedBox(height: 10),
            Text('• 首次进入时系统会请求麦克风权限，请选择「允许」。',
                style: TextStyle(color: colors.onSurface)),
            Text('• 若之前拒绝了，请到系统「设置 → 应用 → 若澜 → 权限」中开启麦克风。',
                style: TextStyle(color: colors.onSurface)),
            if (!available) ...[
              const SizedBox(height: 12),
              Text('⚠️ 当前设备语音识别暂不可用（可能未安装离线语音服务或未授权）。',
                  style: TextStyle(color: colors.errorText)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消', style: TextStyle(color: colors.onSurfaceMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('继续通话', style: TextStyle(color: colors.primaryFg)),
          ),
        ],
      ),
    );
    if (proceed == true) voice.enterCallMode();
  }
}
