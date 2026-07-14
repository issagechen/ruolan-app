import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/voice_provider.dart';
import '../../providers/settings_provider.dart';

class InputBar extends StatefulWidget {
  const InputBar({super.key});
  @override State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override void initState() { super.initState(); _controller.addListener(() => setState(() {})); }
  @override void dispose() { _controller.dispose(); _focusNode.dispose(); super.dispose(); }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final chat = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();
    chat.sendMessage(text, settings.profile, voice: context.read<VoiceProvider>());
    _controller.clear();
  }

  void _voiceInput() {
    _focusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请点击键盘上的麦克风进行语音输入'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: Row(children: [
        GestureDetector(
          onTap: _voiceInput,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.mic, color: Color(0xFF8B5E3C), size: 26),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _controller, focusNode: _focusNode, maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '说点什么吧~', hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true, fillColor: const Color(0xFFF5F0EC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: hasText ? _sendMessage : null,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: hasText ? const Color(0xFF8B5E3C) : const Color(0xFFD5C4B5)),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
          ),
        ),
      ])),
    );
  }
}
