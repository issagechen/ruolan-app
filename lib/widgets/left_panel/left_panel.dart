import '../../theme/ruolan_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/voice_provider.dart';
import '../../providers/settings_provider.dart';
import 'top_bar.dart';
import 'avatar_header.dart';
import 'chat_area.dart';
import 'input_bar.dart';

class LeftPanel extends StatelessWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RuolanColors.of(context).background,
      ),
      child: Column(
        children: [
          const TopBar(),
          const AvatarHeader(),
          Divider(height: 1, thickness: 0.5, color: RuolanColors.of(context).border),
          const Expanded(child: ChatArea()),
          const _CallController(),
          const _ModelErrorBanner(),
          const _SuggestedReplies(),
          const InputBar(),
        ],
      ),
    );
  }
}

/// Manages the voice call loop: listen -> send -> speak -> listen
class _CallController extends StatefulWidget {
  const _CallController();
  @override
  State<_CallController> createState() => _CallControllerState();
}

class _CallControllerState extends State<_CallController> {
  bool _loopRunning = false;
  late final VoiceProvider _voiceProv;

  @override
  void initState() {
    super.initState();
    _voiceProv = context.read<VoiceProvider>();
    _voiceProv.addListener(_onVoiceChanged);
    // If already in call mode when widget first mounts, start looping
    if (_voiceProv.isInCallMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
    }
  }

  @override
  void dispose() {
    _voiceProv.removeListener(_onVoiceChanged);
    _loopRunning = false;
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    _tryStart();
  }

  void _tryStart() {
    if (_voiceProv.isInCallMode && !_loopRunning) {
      _startCallLoop();
    } else if (!_voiceProv.isInCallMode) {
      _loopRunning = false;
    }
  }

  void _startCallLoop() {
    _loopRunning = true;
    _runCallLoop();
  }

  Future<void> _runCallLoop() async {
    // 识别无结果（空/未识别）的连续重试上限：达到上限后退出本轮，避免无限静默重试（VOC-004）。
    const int maxNoResult = 3;
    int noResultCount = 0;

    while (_loopRunning && mounted) {
      if (!_voiceProv.isInCallMode) break;

      // ---- LISTENING ----
      _voiceProv.setCallState(CallState.listening, statusText: '正在聆听...');
      await Future.delayed(const Duration(milliseconds: 400));

      String? text;
      bool listenFailed = false;
      try {
        text = await _voiceProv.listenOnce();
      } catch (_) {
        text = null;
        listenFailed = true;
      }

      if (!mounted || !_loopRunning || !_voiceProv.isInCallMode) break;

      if (text == null || text.trim().isEmpty) {
        noResultCount++;
        if (listenFailed) {
          // 识别过程异常（如引擎错误）：明确提示，但不计入「无结果」上限，给一次重试机会。
          _voiceProv.setCallState(CallState.idle, statusText: '识别出错，请再说一次');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (noResultCount >= maxNoResult) {
          // 连续多次无结果：明确提示并退出本轮，需用户重新发起（VOC-004 边界场景）。
          _voiceProv.setCallState(CallState.idle,
            statusText: '未识别到语音，已退出本轮（连续 $maxNoResult 次）。点击通话键可重新开始');
          await Future.delayed(const Duration(seconds: 3));
          break;
        }
        _voiceProv.setCallState(CallState.idle,
          statusText: '未识别到语音，再试一次（$noResultCount/$maxNoResult）');
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      // 识别到有效内容：重置无结果计数。
      noResultCount = 0;

      // ---- THINKING ----
      _voiceProv.setCallState(CallState.thinking, statusText: '思考中...');

      try {
        final chat = context.read<ChatProvider>();
        final settings = context.read<SettingsProvider>();
        await chat.sendMessage(text.trim(), settings.profile, voice: _voiceProv);
      } catch (_) {
        if (mounted) {
          _voiceProv.setCallState(CallState.idle, statusText: '出错了，重试中...');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
      }

      if (!mounted || !_loopRunning || !_voiceProv.isInCallMode) break;

      // ---- IDLE (brief pause before next listen) ----
      _voiceProv.setCallState(CallState.idle, statusText: '');
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (mounted) {
      _voiceProv.setCallState(CallState.idle, statusText: '');
    }
    _loopRunning = false;
  }

  // -------- UI --------

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voice, _) {
        if (!voice.isInCallMode) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: RuolanColors.of(context).accentWarm,
            border: Border(top: BorderSide(color: RuolanColors.of(context).border, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIcon(voice.callState),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  voice.callStatusText.isNotEmpty ? voice.callStatusText : '语音通话中...',
                  style: TextStyle(fontSize: 14, color: RuolanColors.of(context).primaryFg, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  _loopRunning = false;
                  voice.exitCallMode();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_end, color: Colors.red, size: 18),
                      SizedBox(width: 4),
                      Text('挂断', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(CallState state) {
    switch (state) {
      case CallState.listening:
        return _PulsingDot(color: RuolanColors.of(context).statusOk);
      case CallState.thinking:
        return const _ThinkingDots();
      case CallState.speaking:
        return _PulsingDot(color: RuolanColors.of(context).statusWarn);
      case CallState.idle:
        return Icon(Icons.mic, color: RuolanColors.of(context).primaryFg, size: 20);
    }
  }
}

// ---- 模型加载失败横幅 + 重试 ----
class _ModelErrorBanner extends StatelessWidget {
  const _ModelErrorBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        if (chat.errorMessage == null) return const SizedBox.shrink();
        final settings = context.read<SettingsProvider>();
        final voice = context.read<VoiceProvider>();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RuolanColors.of(context).errorBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RuolanColors.of(context).errorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: RuolanColors.of(context).errorText, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(chat.errorTitle ?? '出错了',
                        style: TextStyle(fontWeight: FontWeight.w600, color: RuolanColors.of(context).errorText)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(chat.errorMessage!, style: TextStyle(fontSize: 13, color: RuolanColors.of(context).errorText2)),
              if (chat.errorDetail != null) ...[
                const SizedBox(height: 4),
                Text('· ${chat.errorDetail!}',
                    style: TextStyle(fontSize: 12, color: RuolanColors.of(context).errorText2)),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (chat.errorCanRetry)
                    TextButton(
                      onPressed: () => chat.retry(profile: settings.profile, voice: voice),
                      child: Text('重试', style: TextStyle(color: RuolanColors.of(context).primaryFg, fontWeight: FontWeight.w600)),
                    ),
                  TextButton(
                    onPressed: () => chat.clearError(),
                    child: Text('知道了', style: TextStyle(color: RuolanColors.of(context).onSurfaceMuted)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---- 建议回复快捷条 ----
class _SuggestedReplies extends StatelessWidget {
  const _SuggestedReplies();

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voice, _) {
        if (voice.isInCallMode) return const SizedBox.shrink();
        return Consumer<ChatProvider>(
          builder: (context, chat, _) {
            if (chat.isLoading || chat.errorMessage != null) return const SizedBox.shrink();
            final settings = context.read<SettingsProvider>();
            final replies = settings.profile.suggestedReplies;
            if (replies.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: replies.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final c = context.read<ChatProvider>();
                          final s = context.read<SettingsProvider>();
                          c.sendMessage(r, s.profile);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: RuolanColors.of(context).chipBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: RuolanColors.of(context).border),
                          ),
                          child: Text(r, style: TextStyle(fontSize: 13, color: RuolanColors.of(context).primaryFg)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---- Animated indicators ----

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(widget.color.withValues(alpha: 0.4), widget.color, _ctrl.value),
          ),
        );
      },
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.25) % 1.0;
            final opacity = phase < 0.5 ? phase * 2 : 2 - phase * 2;
            return Container(
              width: 6, height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RuolanColors.of(context).primaryFg.withValues(alpha: 0.3 + opacity * 0.7),
              ),
            );
          }),
        );
      },
    );
  }
}
