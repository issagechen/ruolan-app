class SessionMeta {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String summaryText;
  final int summarizedCount;

  SessionMeta({
    required this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.summaryText = '',
    this.summarizedCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'summary_text': summaryText,
        'summarized_count': summarizedCount,
      };

  factory SessionMeta.fromMap(Map<String, dynamic> map) => SessionMeta(
        id: map['id'] as String,
        title: map['title'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        summaryText: (map['summary_text'] as String?) ?? '',
        summarizedCount: (map['summarized_count'] as int?) ?? 0,
      );

  SessionMeta copyWith({
    String? title,
    String? summaryText,
    int? summarizedCount,
  }) =>
      SessionMeta(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        summaryText: summaryText ?? this.summaryText,
        summarizedCount: summarizedCount ?? this.summarizedCount,
      );
}
