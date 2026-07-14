import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  void _copyText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制', style: TextStyle(fontSize: 13)),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _copyText(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) _buildAvatar(),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF8B5E3C) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 15,
                        color: isUser ? Colors.white : const Color(0xFF3C3C3C),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) _buildAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? const Color(0xFF6D9EEB) : const Color(0xFFE8C4A8),
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
