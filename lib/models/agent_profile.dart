class AgentProfile {
  final String id;
  String name;
  String personaDescription;
  String voice;
  String introduction;
  String openingLine;
  List<String> suggestedReplies;
  String? avatarPath;
  String? characterImagePath;

  AgentProfile({
    required this.id,
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
    String? id,
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
      id: id ?? this.id,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'personaDescription': personaDescription,
        'voice': voice,
        'introduction': introduction,
        'openingLine': openingLine,
        'suggestedReplies': suggestedReplies,
        'avatarPath': avatarPath,
        'characterImagePath': characterImagePath,
      };

  factory AgentProfile.fromJson(Map<String, dynamic> json) => AgentProfile(
        id: json['id'] as String? ?? 'default',
        name: json['name'] as String? ?? '若澜',
        personaDescription: json['personaDescription'] as String? ?? '',
        voice: json['voice'] as String? ?? '默认',
        introduction: json['introduction'] as String? ?? '',
        openingLine:
            json['openingLine'] as String? ?? '你好呀，我是若澜，很高兴遇见你~',
        suggestedReplies: (json['suggestedReplies'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        avatarPath: json['avatarPath'] as String?,
        characterImagePath: json['characterImagePath'] as String?,
      );
}
