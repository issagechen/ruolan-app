import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruolan_app/utils/think_filter.dart';

Future<String> _collect(Stream<String> stream) async {
  final buf = StringBuffer();
  await for (final c in stream) {
    buf.write(c);
  }
  return buf.toString();
}

void main() {
  test('无思考块时原样输出', () async {
    final out = await _collect(
      Stream.fromIterable(['你好', '世界']).transform(const ThinkTagFilter()),
    );
    expect(out, '你好世界');
  });

  test('完整思考块被移除，后续正文保留', () async {
    final out = await _collect(
      Stream.value('<think>让我想想</think>你好呀').transform(const ThinkTagFilter()),
    );
    expect(out, '你好呀');
  });

  test('多个思考块均被移除', () async {
    final out = await _collect(
      Stream.value('A<think>1</think>B<think>2</think>C').transform(const ThinkTagFilter()),
    );
    expect(out, 'ABC');
  });

  test('未闭合思考块：其后的内容被隐藏', () async {
    final out = await _collect(
      Stream.value('前缀<think>还没结束的内容').transform(const ThinkTagFilter()),
    );
    expect(out, '前缀');
  });

  test('思考块含换行也被移除', () async {
    final out = await _collect(
      Stream.value('<think>\nline1\nline2\n</think>结果').transform(const ThinkTagFilter()),
    );
    expect(out, '结果');
  });

  test('流式分片（标签完整到达）正确拼装且不重复', () async {
    final tokens = ['请', '思考', '<think>内部推理</think>', '答案是42'];
    final out = await _collect(
      Stream.fromIterable(tokens).transform(const ThinkTagFilter()),
    );
    expect(out, '请思考答案是42');
  });

  test('流式分片：思考内容最终不出现（已知边界：极短 "<thi" 前缀可能瞬间闪现）', () async {
    final tokens = ['<thi', 'nk>秘密', '</think>', '正文'];
    final out = await _collect(
      Stream.fromIterable(tokens).transform(const ThinkTagFilter()),
    );
    expect(out, isNot(contains('秘密')));
    expect(out, isNot(contains('<think>')));
  });
}
