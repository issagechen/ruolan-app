/// 单个本地 GGUF 模型的描述（INF-006 模型管理）。
///
/// 信息来自原生层 `listModels` 扫描结果（路径/名称/字节大小），
/// 量化等级与参数规模从文件名推断（不读取模型内部元数据，避免大文件 IO）。
class ModelInfo {
  final String path;
  final String name;
  final int sizeBytes;

  const ModelInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  /// 从原生 `listModels` 返回的 map 构造。
  factory ModelInfo.fromMap(Map<dynamic, dynamic> map) {
    return ModelInfo(
      path: (map['path'] as String?) ?? '',
      name: (map['name'] as String?) ?? (map['path'] as String? ?? '').split('/').last,
      sizeBytes: (map['sizeBytes'] as int?) ?? 0,
    );
  }

  /// 量化等级推断，例如 Q4_K_M / Q8_0 / F16 / IQ3_XXS。
  String get quantization {
    final m = _quantRegExp.firstMatch(name.toUpperCase());
    return m?.group(0) ?? '未知';
  }

  /// 参数规模推断，例如 7B / 1.5B。
  String get paramScale {
    final m = _paramRegExp.firstMatch(name.toUpperCase());
    return m?.group(0) ?? '';
  }

  /// 人类可读的大小，例如 4.1 GB。
  String get sizeText => _formatSize(sizeBytes);

  /// 用于列表展示的副标题。
  String get subtitle {
    final parts = <String>[quantization];
    if (paramScale.isNotEmpty) parts.add(paramScale);
    return '${parts.join(' · ')} · $sizeText';
  }

  static final RegExp _quantRegExp =
      RegExp(r'(?:IQ)?[QFB]\d+(?:_[A-Z0-9]+)*');
  static final RegExp _paramRegExp = RegExp(r'\d+(?:\.\d+)?B\b');

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final s = i >= 2 ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
    return '$s ${units[i]}';
  }
}
