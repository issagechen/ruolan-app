import 'dart:async';

/// 过滤 DeepSeek-R1 等模型的 <think>...</think> 推理过程。
/// 在流式展示与最终落库时隐藏思考块，使其不进入用户可见文本与历史。
///
/// 实现说明：累计原始 token，计算「稳定可见前缀」，仅把新增部分(delta)下发，
/// 因此不会出现重复文本。已知边界：未完整到达 `<think>` 前的极短前缀(如 `<thi`)
/// 可能瞬间闪现，随后被裁剪，属可接受的 v1 行为。
class ThinkTagFilter extends StreamTransformerBase<String, String> {
  const ThinkTagFilter();

  @override
  Stream<String> bind(Stream<String> stream) {
    late final StreamController<String> ctrl;
    final raw = StringBuffer();
    var emitted = 0;

    String visibleOf(String r) {
      var s = r;
      const open = '<think>';
      const close = '</think>';
      // 1) 去掉所有已完整闭合的思考块
      var ci = s.indexOf(close);
      while (ci != -1) {
        final oi = s.lastIndexOf(open, ci);
        s = (oi == -1)
            ? s.substring(ci + close.length)
            : s.substring(0, oi) + s.substring(ci + close.length);
        ci = s.indexOf(close);
      }
      // 2) 未闭合的开启标签之后的内容全部隐藏
      final oi = s.indexOf(open);
      if (oi != -1) s = s.substring(0, oi);
      return s;
    }

    void onData(String token) {
      raw.write(token);
      final vis = visibleOf(raw.toString());
      if (vis.length > emitted) {
        ctrl.add(vis.substring(emitted));
        emitted = vis.length;
      }
    }

    ctrl = StreamController<String>(
      onListen: () => stream.listen(
        onData,
        onError: ctrl.addError,
        onDone: ctrl.close,
      ),
    );
    return ctrl.stream;
  }
}
