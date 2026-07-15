import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../utils/prompt_builder.dart';
import '../models/agent_profile.dart';
import '../config/api_config.dart';
import '../models/session.dart';
import '../config/inference_settings.dart';
import '../services/model_settings.dart';
import 'voice_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final List<Message> _messages = [];
  bool _isLoading = false;
  String _streamingContent = '';
  // 防止同一会话并发进入生成（主回复 + 摘要共用单模型，避免 token 流混淆）。
  bool _busy = false;

  // 生成中断控制：持有当前流的订阅与完成器，供 stop() 取消（REQ-CHAT-008）。
  StreamSubscription<String>? _sub;
  Completer<void>? _genCompleter;
  bool _stopRequested = false;

  // 编辑上一条：由气泡触发，把被编辑消息原文回填输入框（InputBar 注册该回调）。
  void Function(String)? onRequestEdit;

  // 多会话：当前会话 id 与会话列表
  String _currentSessionId = StorageService.kDefaultSessionId;
  final List<SessionMeta> _sessions = [];

  // 错误态：用于加载失败/生成中断时向 UI 展示引导与重试，不写入对话气泡。
  String? _errorTitle;
  String? _errorMessage;
  String? _errorDetail;
  bool _errorCanRetry = false;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get streamingContent => _streamingContent;

  String get currentSessionId => _currentSessionId;
  List<SessionMeta> get sessions => List.unmodifiable(_sessions);

  String? get errorTitle => _errorTitle;
  String? get errorMessage => _errorMessage;
  String? get errorDetail => _errorDetail;
  bool get errorCanRetry => _errorCanRetry;

  /// 失败消息可重发：存在错误态且最后一条为用户消息（助手回复未完成，REQ-CHAT-008）。
  bool get canResend =>
      _errorTitle != null &&
      _messages.isNotEmpty &&
      _messages.last.role == 'user' &&
      !_isLoading;

  Future<void> loadHistory() async {
    try {
      _sessions.clear();
      _sessions.addAll(await StorageService.listSessions());
      if (_sessions.isEmpty) {
        await StorageService.createSession(
          SessionMeta(id: StorageService.kDefaultSessionId, title: '默认会话'),
        );
        _sessions.addAll(await StorageService.listSessions());
      }
      _currentSessionId = StorageService.kDefaultSessionId;
      final history = await StorageService.loadMessages(sessionId: _currentSessionId);
      _messages.clear();
      _messages.addAll(history);
    } catch (_) {}
    _safeNotify();
  }

  Future<void> sendMessage(String content, AgentProfile profile, {VoiceProvider? voice}) async {
    if (_busy || content.trim().isEmpty) return;
    _busy = true;
    try {
      final userMsg = Message(role: 'user', content: content, sessionId: _currentSessionId);
      _messages.add(userMsg);
      _saveMsgSafe(userMsg);
      _safeNotify();

      await _generate(profile, voice: voice);
    } finally {
      _busy = false;
    }
  }

  /// 在模型加载失败等可恢复错误后重新生成（用户消息已在 _messages 中，不会重复）。
  Future<void> retry({required AgentProfile profile, VoiceProvider? voice}) async {
    if (_busy || _messages.isEmpty) return;
    _busy = true;
    try {
      await _generate(profile, voice: voice);
    } finally {
      _busy = false;
    }
  }

  /// 立即停止当前生成（REQ-CHAT-008）：解除 _generate 的 await 并通知底层停止推理，
  /// 已生成的文本会作为助手消息保留。
  Future<void> stop() async {
    if (!_isLoading) return;
    _stopRequested = true;
    final sub = _sub;
    _genCompleter?.complete();
    await _chatService.stop();
    await sub?.cancel();
  }

  /// 编辑上一条用户消息（REQ-CHAT-008）：撤销该轮（删除该用户消息及其后的助手回复），
  /// 并把原文回填输入框供修改后重新发送。
  void editLastUser() {
    if (_isLoading || _busy) return;
    final idx = _messages.lastIndexWhere((m) => m.role == 'user');
    if (idx == -1) return;
    final content = _messages[idx].content;
    for (int i = _messages.length - 1; i >= idx; i--) {
      final m = _messages[i];
      _messages.removeAt(i);
      StorageService.deleteMessage(m.id).catchError((_) => 0);
    }
    _clearError();
    onRequestEdit?.call(content);
    _safeNotify();
  }

  /// 新建会话并切换。
  Future<void> newSession() async {
    final id = 's_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await StorageService.createSession(SessionMeta(id: id, title: '新会话'));
      _sessions.clear();
      _sessions.addAll(await StorageService.listSessions());
    } catch (_) {}
    _currentSessionId = id;
    _messages.clear();
    _clearError();
    _safeNotify();
  }

  /// 切换到指定会话并加载其历史。
  Future<void> switchSession(String id) async {
    if (id == _currentSessionId) return;
    _currentSessionId = id;
    try {
      final history = await StorageService.loadMessages(sessionId: id);
      _messages.clear();
      _messages.addAll(history);
    } catch (_) {}
    _clearError();
    _safeNotify();
  }

  Future<void> renameSession(String id, String title) async {
    try {
      await StorageService.renameSession(id, title);
      _sessions.clear();
      _sessions.addAll(await StorageService.listSessions());
    } catch (_) {}
    _safeNotify();
  }

  Future<void> deleteSession(String id) async {
    try {
      await StorageService.deleteSession(id);
      _sessions.clear();
      _sessions.addAll(await StorageService.listSessions());
    } catch (_) {}
    if (_currentSessionId == id) {
      _currentSessionId =
          _sessions.isNotEmpty ? _sessions.first.id : StorageService.kDefaultSessionId;
    }
    try {
      if (_sessions.isEmpty) {
        await StorageService.createSession(
          SessionMeta(id: StorageService.kDefaultSessionId, title: '默认会话'),
        );
        _sessions.addAll(await StorageService.listSessions());
        _currentSessionId = StorageService.kDefaultSessionId;
      }
      final history = await StorageService.loadMessages(sessionId: _currentSessionId);
      _messages.clear();
      _messages.addAll(history);
    } catch (_) {}
    _clearError();
    _safeNotify();
  }

  /// 清除错误横幅（用户点击「知道了」）。
  void clearError() {
    _clearError();
    _safeNotify();
  }

  Future<void> _generate(AgentProfile profile, {VoiceProvider? voice}) async {
    _isLoading = true;
    _streamingContent = '';
    _stopRequested = false;
    _clearError();
    _safeNotify();

    final apiMessages = _buildApiMessages(profile);
    final buffer = StringBuffer();
    bool errored = false;

    final completer = Completer<void>();
    _genCompleter = completer;
    final sub = _chatService.sendMessageStream(apiMessages).listen(
      (chunk) {
        buffer.write(chunk);
        _streamingContent = buffer.toString();
        _safeNotify();
      },
      onError: (e) {
        errored = true;
        _setErrorFromException(e);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: false,
    );
    _sub = sub;

    await completer.future;

    _sub = null;
    _genCompleter = null;

    // 用户主动停止：保留已生成部分作为助手消息，立即结束（REQ-CHAT-008）。
    if (_stopRequested) {
      _stopRequested = false;
      _isLoading = false;
      final text = buffer.toString();
      if (text.isNotEmpty) {
        final msg = Message(role: 'assistant', content: text, sessionId: _currentSessionId);
        _messages.add(msg);
        _saveMsgSafe(msg);
        try { await StorageService.touchSession(_currentSessionId); } catch (_) {}
      }
      _streamingContent = '';
      _safeNotify();
      return;
    }

    final text = buffer.toString();
    if (text.isNotEmpty) {
      final msg = Message(role: 'assistant', content: text, sessionId: _currentSessionId);
      _messages.add(msg);
      _saveMsgSafe(msg);
      try { await StorageService.touchSession(_currentSessionId); } catch (_) {}
      if (voice != null && voice.isSpeakerOn && !errored) {
        if (voice.isInCallMode) {
          await voice.speakAndWait(text);
        } else {
          try { await voice.speak(text); } catch (_) {}
        }
      }
    }

    _isLoading = false;
    _streamingContent = '';

    // 长会话上下文摘要策略（CHAT-004）：主回复落库后尝试生成/更新滚动摘要。
    // 失败不影响主对话；await 确保在单模型上不与下一次生成并发。
    try { await _maybeSummarize(); } catch (_) {}

    _safeNotify();
  }

  void _setErrorFromException(Object e) {
    if (e is ModelLoadException) {
      _errorTitle = '模型未加载';
      _errorMessage = '无法加载本地模型，请确认模型文件已放置到以下路径之一：';
      _errorDetail = e.modelPath.isNotEmpty ? e.modelPath : '(应用内部 files/models 或 /sdcard/models)';
      _errorCanRetry = true;
    } else if (e is GenerationException) {
      _errorTitle = '生成中断';
      _errorMessage = '模型推理过程中断：${e.message}';
      _errorCanRetry = false;
    } else {
      _errorTitle = '出错了';
      _errorMessage = e.toString();
      _errorCanRetry = false;
    }
  }

  void _clearError() {
    _errorTitle = null;
    _errorMessage = null;
    _errorDetail = null;
    _errorCanRetry = false;
  }

  void _safeNotify() { try { notifyListeners(); } catch (_) {} }

  void _saveMsgSafe(Message msg) {
    StorageService.saveMessage(msg).catchError((_) => 0);
  }

  List<Map<String, String>> _buildApiMessages(AgentProfile profile) {
    final list = <Map<String, String>>[
      {'role': 'system', 'content': PromptBuilder.buildSystemPrompt(profile)},
    ];
    final session = _currentSession();
    const maxMsgs = ApiConfig.maxContextRounds * 2;
    final recent = _messages.length > maxMsgs
        ? _messages.sublist(_messages.length - maxMsgs)
        : _messages;
    if (session.summaryText.isNotEmpty) {
      list.add({
        'role': 'system',
        'content':
            '以下是本次对话之前的内容摘要，请结合它理解用户的历史偏好与未完成的议题：\n${session.summaryText}',
      });
    }
    for (final m in recent) {
      list.add({'role': m.role, 'content': m.content});
    }
    return list;
  }

  SessionMeta _currentSession() {
    for (final s in _sessions) {
      if (s.id == _currentSessionId) return s;
    }
    return SessionMeta(id: _currentSessionId, title: '默认会话');
  }

  /// 长会话上下文摘要策略（CHAT-004）：消息数超过保留窗口且溢出累积到一定量时，
  /// 用本地模型对溢出部分生成滚动摘要，写入会话并作为 system 上下文前置注入。
  Future<void> _maybeSummarize() async {
    final session = _currentSession();
    const keepRecent = ApiConfig.maxContextRounds * 2;
    if (_messages.length <= keepRecent) return;
    final overflowCount = _messages.length - keepRecent - session.summarizedCount;
    if (overflowCount < 4) return; // 累积一定量再摘要，避免过度调用模型

    final overflow = _messages.sublist(session.summarizedCount, _messages.length - keepRecent);
    final overflowMaps = overflow.map((m) => {'role': m.role, 'content': m.content}).toList();
    String newSummary;
    try {
      newSummary = await _chatService.summarize(overflowMaps);
    } catch (_) {
      return; // 摘要失败不影响主对话
    }
    if (newSummary.isEmpty) return;

    final combined = session.summaryText.isEmpty ? newSummary : '${session.summaryText}\n$newSummary';
    final newCount = _messages.length - keepRecent;
    final updated = session.copyWith(summaryText: combined, summarizedCount: newCount);
    final idx = _sessions.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _sessions[idx] = updated;
    try {
      await StorageService.updateSessionSummary(updated.id, combined, newCount);
    } catch (_) {}
  }

  Future<void> clearChat() async {
    _messages.clear();
    try { await StorageService.clearMessages(_currentSessionId); } catch (_) {}
    _safeNotify();
  }

  /// 切换本地模型（INF-006）：持久化选择 → 卸载当前模型 → 立即加载选中模型（热重载）。
  /// 返回是否加载成功。生成进行中会拒绝切换（返回 false）。
  Future<bool> switchModel(String path) async {
    if (_busy) return false;
    try {
      await ModelSettings.setSelectedPath(path);
      final inference = await InferenceSettings.load();
      if (await _chatService.isModelLoaded()) await _chatService.unload();
      final loaded = await _chatService.loadModelWithPath(
        path,
        ctxSize: inference.ctxSize,
        nThreads: inference.threads,
      );
      return loaded;
    } catch (_) {
      return false;
    }
  }
}
