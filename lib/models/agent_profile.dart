class AgentProfile {
  String name;
  String personaDescription;
  String voice;
  String introduction;
  String openingLine;
  List<String> suggestedReplies;
  String? avatarPath;
  String? characterImagePath;

  AgentProfile({
    this.name = '若澜',
    this.personaDescription = '',
    this.voice = '默认',
    this.introduction = '',
    this.openingLine = '你好呀，我是若澜，很高兴遇见你~',
    this.suggestedReplies = const [],
    this.avatarPath,
    this.characterImagePath,
  });

  AgentProfile copyWith({
    String? name,
    String? personaDescription,
    String? voice,
    String? introduction,
    String? openingLine,
    List<String>? suggestedReplies,
    String? avatarPath,
    String? characterImagePath,
  }) {
    return AgentProfile(
      name: name ?? this.name,
      personaDescription: personaDescription ?? this.personaDescription,
      voice: voice ?? this.voice,
      introduction: introduction ?? this.introduction,
      openingLine: openingLine ?? this.openingLine,
      suggestedReplies: suggestedReplies ?? this.suggestedReplies,
      avatarPath: avatarPath ?? this.avatarPath,
      characterImagePath: characterImagePath ?? this.characterImagePath,
    );
  }
}
