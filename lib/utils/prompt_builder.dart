import '../config/persona_config.dart';
import '../models/agent_profile.dart';

class PromptBuilder {
  static String buildSystemPrompt(AgentProfile profile) {
    final buffer = StringBuffer();
    buffer.writeln(PersonaConfig.defaultPersona);

    if (profile.personaDescription.isNotEmpty) {
      buffer.writeln('\n补充设定：${profile.personaDescription}');
    }

    if (profile.introduction.isNotEmpty) {
      buffer.writeln('\n你对用户的自我介绍：${profile.introduction}');
    }

    return buffer.toString().trim();
  }
}
