import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// 推理参数（运行时可调，与人格画像 AgentProfile 解耦）。
///
/// 说明：
/// - 上下文长度(ctxSize)与线程数(threads)在模型加载时生效，修改后需重新加载模型才能应用；
/// - 单次最大生成(maxTokens)、温度(temperature)、Top-P(topP)在每次推理时读取，保存后立即生效。
///
/// temperature/topP 已打通原生采样链（C++ sampler chain：temp -> top-p -> dist；
/// temp<=0 时退回 greedy）。默认值参考 DeepSeek-R1-Distill 建议（低温更利于推理连贯）。
class InferenceSettings {
  final int ctxSize;
  final int maxTokens;
  final int threads;
  final double temperature;
  final double topP;

  const InferenceSettings({
    int ctxSize = ApiConfig.localCtxSize,
    int maxTokens = ApiConfig.maxTokens,
    int threads = ApiConfig.localThreads,
    double temperature = 0.7,
    double topP = 0.9,
  })  : ctxSize = ctxSize < 1024 ? 1024 : (ctxSize > 8192 ? 8192 : ctxSize),
        maxTokens = maxTokens < 64 ? 64 : (maxTokens > 4096 ? 4096 : maxTokens),
        threads = threads < 1 ? 1 : (threads > 8 ? 8 : threads),
        temperature = temperature < 0 ? 0 : (temperature > 2 ? 2 : temperature),
        topP = topP < 0 ? 0 : (topP > 1 ? 1 : topP);

  static Future<InferenceSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return InferenceSettings(
      ctxSize: prefs.getInt('infer_ctx_size') ?? ApiConfig.localCtxSize,
      maxTokens: prefs.getInt('infer_max_tokens') ?? ApiConfig.maxTokens,
      threads: prefs.getInt('infer_threads') ?? ApiConfig.localThreads,
      temperature: prefs.getDouble('infer_temperature') ?? 0.7,
      topP: prefs.getDouble('infer_top_p') ?? 0.9,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('infer_ctx_size', ctxSize);
    await prefs.setInt('infer_max_tokens', maxTokens);
    await prefs.setInt('infer_threads', threads);
    await prefs.setDouble('infer_temperature', temperature);
    await prefs.setDouble('infer_top_p', topP);
  }
}
