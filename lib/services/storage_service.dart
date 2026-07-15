import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/session.dart';

class StorageService {
  static Database? _database;
  static const String kDefaultSessionId = 'default';

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ruolan.db');
    _database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            summary_text TEXT NOT NULL DEFAULT '',
            summarized_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            session_id TEXT NOT NULL DEFAULT 'default'
          )
        ''');
        await _ensureDefaultSession(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2：消息表增加会话隔离列；新建会话表；保证 default 会话存在。
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(messages)');
          final names = columns.map((c) => (c['name'] as String?) ?? '').toSet();
          if (!names.contains('session_id')) {
            await db.execute(
              "ALTER TABLE messages ADD COLUMN session_id TEXT NOT NULL DEFAULT 'default'",
            );
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await _ensureDefaultSession(db);
        }
        // v2 -> v3：会话表增加摘要字段，支撑长会话上下文摘要策略（CHAT-004）。
        if (oldVersion < 3) {
          final cols = await db.rawQuery('PRAGMA table_info(sessions)');
          final names = cols.map((c) => (c['name'] as String?) ?? '').toSet();
          if (!names.contains('summary_text')) {
            await db.execute(
              "ALTER TABLE sessions ADD COLUMN summary_text TEXT NOT NULL DEFAULT ''",
            );
          }
          if (!names.contains('summarized_count')) {
            await db.execute(
              "ALTER TABLE sessions ADD COLUMN summarized_count INTEGER NOT NULL DEFAULT 0",
            );
          }
        }
      },
    );
  }

  static Future<void> _ensureDefaultSession(Database db) async {
    final existing = await db.query('sessions', where: 'id = ?', whereArgs: [kDefaultSessionId]);
    if (existing.isEmpty) {
      final now = DateTime.now().toIso8601String();
      await db.insert('sessions', {
        'id': kDefaultSessionId,
        'title': '默认会话',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  static Database get db {
    if (_database == null) throw Exception('Database not initialized');
    return _database!;
  }

  // ---- messages ----
  static Future<int> saveMessage(Message message) async {
    return await db.insert('messages', message.toMap());
  }

  static Future<List<Message>> loadMessages({required String sessionId, int limit = 200}) async {
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  static Future<void> clearMessages(String sessionId) async {
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  /// 按主键删除单条消息（编辑上一条时撤销该轮用，REQ-CHAT-008）。
  static Future<void> deleteMessage(int? id) async {
    if (id == null) return;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ---- sessions ----
  static Future<void> createSession(SessionMeta session) async {
    await db.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<SessionMeta>> listSessions() async {
    final maps = await db.query('sessions', orderBy: 'updated_at DESC');
    return maps.map((m) => SessionMeta.fromMap(m)).toList();
  }

  static Future<void> renameSession(String id, String title) async {
    await db.update(
      'sessions',
      {'title': title, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteSession(String id) async {
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
  }

  static Future<void> touchSession(String id) async {
    await db.update(
      'sessions',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新会话摘要（滚动摘要：已折叠进摘要的消息条数 + 摘要文本）。
  static Future<void> updateSessionSummary(String id, String summaryText, int summarizedCount) async {
    await db.update(
      'sessions',
      {
        'summary_text': summaryText,
        'summarized_count': summarizedCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
