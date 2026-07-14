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
          return SettingsForm(
            initialProfile: settings.profile,
            initialInference: settings.inference,
            onSave: (AgentProfile profile) {
              settings.save(profile);
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
          );
        },
      ),
    );
  }
}
