class Message {
  final int? id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String sessionId;

  Message({
    this.id,
    required this.role,
    required this.content,
    this.sessionId = 'default',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'session_id': sessionId,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as int?,
        role: map['role'] as String,
        content: map['content'] as String,
        sessionId: (map['session_id'] as String?) ?? 'default',
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
