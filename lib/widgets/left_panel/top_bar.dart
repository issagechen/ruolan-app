import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voice_provider.dart';
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
              child: const Icon(Icons.forum_outlined, color: Color(0xFF8B5E3C), size: 24),
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
              child: const Icon(Icons.menu, color: Color(0xFF8B5E3C), size: 28),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8B5E3C),
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
                voice.enterCallMode();
              }
            },
            child: Consumer<VoiceProvider>(
              builder: (context, voice, _) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: voice.isInCallMode
                      ? BoxDecoration(
                          color: const Color(0xFFE57373).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        )
                      : null,
                  child: Icon(
                    voice.isInCallMode ? Icons.call_end : Icons.phone,
                    color: voice.isInCallMode ? Colors.red : const Color(0xFF8B5E3C),
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
                    color: voice.isSpeakerOn ? const Color(0xFF8B5E3C) : Colors.grey,
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
}
