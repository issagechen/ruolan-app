import 'dart:async';
import 'package:flutter/services.dart';

class LlmService {
  static const MethodChannel _methodChannel = MethodChannel('com.ruolan.llama/method');
  static const EventChannel _eventChannel = EventChannel('com.ruolan.llama/stream');
  StreamSubscription? _subscription;
  bool _isModelLoaded = false;
  String? _loadedPath;
  String _lastError = '';
  final StreamController<String> _tokenController = StreamController<String>.broadcast();
  final StreamController<void> _doneController = StreamController<void>.broadcast();
  Stream<String> get tokenStream => _tokenController.stream;
  Stream<void> get doneStream => _doneController.stream;
  String get lastError => _lastError;

  LlmService() {
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'token' && !_tokenController.isClosed) {
          _tokenController.add(event['text'] as String);
        } else if (type == 'done' && !_doneController.isClosed) {
          _doneController.add(null);
        }
      }
    }, onError: (e) { _lastError = e.toString(); try { _tokenController.addError(e); } catch (_) {} });
  }

  Future<bool> isLoaded() async {
    try { _isModelLoaded = await _methodChannel.invokeMethod('isLoaded') ?? false; } catch (_) { _isModelLoaded = false; }
    return _isModelLoaded;
  }

  Future<String> getDefaultModelPath() async {
    try { return await _methodChannel.invokeMethod('defaultModelPath') as String? ?? '/sdcard/models/model.gguf'; }
    catch (_) { return '/sdcard/models/model.gguf'; }
  }

  Future<bool> loadModel({String? modelPath, int ctxSize = 2048, int nThreads = 7}) async {
    try {
      final args = <String, dynamic>{'ctxSize': ctxSize, 'nThreads': nThreads};
      if (modelPath != null) args['modelPath'] = modelPath;
      final result = await _methodChannel.invokeMethod('loadModel', args);
      _isModelLoaded = result == true;
      _loadedPath = _isModelLoaded ? (modelPath ?? await getDefaultModelPath()) : null;
      if (!_isModelLoaded) _lastError = 'Native loadModel returned false';
      return _isModelLoaded;
    } on PlatformException catch (e) { _lastError = '${e.code}: ${e.message}'; _isModelLoaded = false; _loadedPath = null; return false; }
    catch (e) { _lastError = e.toString(); _isModelLoaded = false; _loadedPath = null; return false; }
  }

  /// 当前已加载模型路径；未加载或未知时为 null（INF-006 用于判断是否需要切换）。
  String? get loadedPath => _loadedPath;

  /// 扫描设备上的可用 GGUF 模型（INF-006 模型管理）。
  /// 返回 `[{path, name, sizeBytes}]`；原生未就绪时返回空列表。
  static Future<List<Map<String, dynamic>>> listModels() async {
    try {
      final result = await _methodChannel.invokeMethod('listModels');
      if (result is List) {
        return result
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> generate(String prompt, {int maxTokens = 512, double temperature = 0.7, double topP = 0.9}) async {
    if (!_isModelLoaded) throw Exception('Model not loaded: $_lastError');
    await _methodChannel.invokeMethod('generate', {
      'prompt': prompt,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
    });
  }

  Future<void> stop() async => await _methodChannel.invokeMethod('stop');
  Future<void> unload() async { await _methodChannel.invokeMethod('unload'); _isModelLoaded = false; _loadedPath = null; }

  /// DeepSeek-R1-Distill-Qwen chat template: <|im_start|>role\ncontent<|im_end|>
  String buildChatPrompt(List<Map<String, String>> messages, String systemPrompt) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      buffer.write('<|im_start|>$role\n$content<|im_end|>\n');
    }
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  void dispose() { _subscription?.cancel(); _tokenController.close(); _doneController.close(); }
}
