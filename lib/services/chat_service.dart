import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../config/inference_settings.dart';
import '../config/remote_settings.dart';
import '../utils/think_filter.dart';
import '../services/model_settings.dart';
import 'llm_service.dart';

class ChatService {
  final LlmService? _llmService;

  /// 长会话摘要系统提示：指导模型产出客观、可衔接的对话摘要（CHAT-004）。
  static const String _summarySystemPrompt = '你是一个对话摘要助手。请将以下对话浓缩为简洁、客观的中文摘要，'
      '保留：关键事实、用户明确表达的兴趣与偏好、重要决定或约定、以及尚未完成的议题。'
      '不要编造对话中未出现的内容，不要使用第一人称。'
      '输出纯文本摘要，不要加标题或 Markdown 标记。';

  ChatService() : _llmService = LlmService();

  Stream<String> sendMessageStream(List<Map<String, String>> messages) async* {
    final mode = await RemoteSettings.getMode();
    if (mode == 'local' && _llmService != null) {
      yield* _sendLocalStream(messages);
    } else {
      yield* _sendRemoteStream(messages);
    }
  }

  Stream<String> _sendLocalStream(List<Map<String, String>> messages) {
    final llm = _llmService!;
    final controller = StreamController<String>.broadcast();
    Future.microtask(() => _runLocal(llm, messages, controller).catchError((_) {}));
    return controller.stream;
  }

  Future<void> _runLocal(LlmService llm, List<Map<String, String>> messages, StreamController<String> controller) async {
    try {
      final inference = await InferenceSettings.load();
      if (!await llm.isLoaded()) {
        final selectedPath = await _resolveModelPath(llm);
        final loaded = await llm.loadModel(
          modelPath: selectedPath,
          ctxSize: inference.ctxSize,
          nThreads: inference.threads,
        );
        if (!loaded) {
          controller.addError(ModelLoadException(
            modelPath: selectedPath ?? await llm.getDefaultModelPath(),
            reason: llm.lastError.isEmpty ? '未知错误' : llm.lastError,
          ));
          await _safeClose(controller);
          return;
        }
        // Let the system stabilize after model load
        await Future.delayed(const Duration(milliseconds: 300));
      } else if (llm.loadedPath != await _resolveModelPath(llm)) {
        // 已加载的模型与当前选中不一致（设置内切换过）：先卸载，下次生成再用选中模型。
        await llm.unload();
      }

      final prompt = llm.buildChatPrompt(messages, '');
      final completer = Completer<void>();

      final tokenSub = llm.tokenStream
          .transform(const ThinkTagFilter())
          .listen(
        (token) { if (!controller.isClosed) controller.add(token); },
        onError: (e) {
          if (!controller.isClosed) controller.addError(GenerationException(e.toString()));
          if (!completer.isCompleted) completer.complete();
        },
      );
      final doneSub = llm.doneStream.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await llm.generate(
        prompt,
        maxTokens: inference.maxTokens,
        temperature: inference.temperature,
        topP: inference.topP,
      );
      await completer.future;

      await tokenSub.cancel();
      await doneSub.cancel();
      await _safeClose(controller);
    } catch (e) {
      try { if (!controller.isClosed) controller.add('【异常】$e'); } catch (_) {}
      await _safeClose(controller);
    }
  }

  Future<void> _safeClose(StreamController<String> controller) async {
    try { if (!controller.isClosed) await controller.close(); } catch (_) {}
  }

  Stream<String> _sendRemoteStream(List<Map<String, String>> messages) async* {
    // 运行时读取远程配置；密钥来自系统密钥库，绝不打印到日志。
    final baseUrl = await RemoteSettings.getBaseUrl();
    final apiKey = await RemoteSettings.getApiKey();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ));
    try {
      final response = await dio.post(
        '/chat/completions',
        data: jsonEncode({
          'model': ApiConfig.model,
          'messages': messages,
          'stream': true,
        }),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      String buffer = '';
      await for (final chunk in response.data.stream) {
        buffer += utf8.decode(List<int>.from(chunk));
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                if (delta != null && delta.containsKey('content')) {
                  final content = delta['content'] as String?;
                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
                }
              }
            } catch (_) {}
          }
        }
      }
    } on DioException catch (e) {
      yield '【网络错误】${e.type}: ${e.message}';
    } catch (e) {
      yield '【未知错误】$e';
    } finally {
      dio.close(); // 关闭本次请求 Dio，避免连接泄漏；密钥不在此处日志输出。
    }
  }

  Future<void> stop() async {
    await _llmService?.stop();
  }

  /// 解析当前应加载的模型路径：优先使用设置中选中的模型，否则回退原生默认路径。
  Future<String?> _resolveModelPath(LlmService llm) async {
    final selected = await ModelSettings.getSelectedPath();
    if (selected != null && selected.isNotEmpty) return selected;
    return llm.getDefaultModelPath();
  }

  /// 当前是否有模型已加载（供模型切换判断）。
  Future<bool> isModelLoaded() => _llmService?.isLoaded() ?? Future.value(false);

  /// 卸载当前模型（切换模型时先释放内存中的旧模型）。
  Future<void> unload() => _llmService?.unload() ?? Future.value();

  /// 按指定路径加载模型（切换模型时热重载）。
  Future<bool> loadModelWithPath(String path, {int ctxSize = 2048, int nThreads = 7}) async {
    final llm = _llmService;
    if (llm == null) return false;
    return llm.loadModel(modelPath: path, ctxSize: ctxSize, nThreads: nThreads);
  }

  /// 对给定消息列表生成完整摘要文本（收集流式输出，并过滤 <think> 推理块）。
  /// 用于长会话上下文摘要策略（CHAT-004）。仅支持本地模式。
  Future<String> summarize(List<Map<String, String>> messages) async {
    final llm = _llmService;
    final mode = await RemoteSettings.getMode();
    if (llm == null || mode != 'local') {
      throw StateError('摘要仅支持本地模式');
    }
    if (!await llm.isLoaded()) {
      final selectedPath = await _resolveModelPath(llm);
      final loaded = await llm.loadModel(
        modelPath: selectedPath,
        ctxSize: ApiConfig.localCtxSize,
        nThreads: ApiConfig.localThreads,
      );
      if (!loaded) {
        throw ModelLoadException(
          modelPath: selectedPath ?? await llm.getDefaultModelPath(),
          reason: llm.lastError.isEmpty ? '未知错误' : llm.lastError,
        );
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final prompt = llm.buildChatPrompt(messages, _summarySystemPrompt);
    final raw = <String>[];
    final done = Completer<void>();
    final tokenSub = llm.tokenStream.listen(raw.add, onError: done.completeError);
    final doneSub = llm.doneStream.listen((_) => done.complete());
    try {
      await llm.generate(prompt, maxTokens: 320, temperature: 0.3, topP: 0.9);
      await done.future;
    } finally {
      await tokenSub.cancel();
      await doneSub.cancel();
    }
    final filtered = await Stream<String>.fromIterable(raw)
        .transform(const ThinkTagFilter())
        .join();
    return filtered.trim();
  }

  void dispose() {
    _llmService?.dispose();
  }
}

/// 本地模型加载失败（文件缺失/权限/格式错误等），由 UI 层捕获后展示引导与重试。
class ModelLoadException implements Exception {
  final String modelPath;
  final String reason;
  const ModelLoadException({required this.modelPath, required this.reason});
  @override
  String toString() => '模型加载失败: $reason';
}

/// 模型推理过程中断（native 抛错）。
class GenerationException implements Exception {
  final String message;
  const GenerationException(this.message);
  @override
  String toString() => message;
}

// 思考过程过滤器已提取为公共类 `ThinkTagFilter`（见 lib/utils/think_filter.dart），
// 便于单元测试；chat_service.dart 在流式层使用它隐藏 <think>...</think> 推理块。