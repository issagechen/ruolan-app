import '../config/persona_config.dart';
import '../models/agent_profile.dart';

class PromptBuilder {
  static String buildSystemPrompt(AgentProfile profile) {
    final buffer = StringBuffer();
    // 多角色（AVT-003）：每个角色以自身设定作为 system prompt 主体；
    // 仅当设定为空时回退到默认若澜人设，保证首装可用。
    final persona = profile.personaDescription.trim().isNotEmpty
        ? profile.personaDescription.trim()
        : PersonaConfig.defaultPersona;
    buffer.writeln(persona);

    if (profile.introduction.isNotEmpty) {
      buffer.writeln('\n你对用户的自我介绍：${profile.introduction}');
    }

    return buffer.toString().trim();
  }
}
