import '../../theme/ruolan_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final bool isFailed;
  final bool isStreaming;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.onResend,
    this.onEdit,
    this.isFailed = false,
    this.isStreaming = false,
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
            if (!isUser) _buildAvatar(context),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? RuolanColors.of(context).primaryFg : RuolanColors.of(context).surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isFailed
                      ? Border.all(color: RuolanColors.of(context).errorBorder, width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContent(context),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser ? Colors.white70 : RuolanColors.of(context).onSurfaceMuted,
                      ),
                    ),
                    if (onResend != null || onEdit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onEdit != null) _buildAction(context, '编辑', Icons.edit, onEdit!),
                            if (onEdit != null && onResend != null)
                              const SizedBox(width: 8),
                            if (onResend != null) _buildAction(context, '重发', Icons.refresh, onResend!),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) _buildAvatar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // 用户消息保持纯文本；助手流式阶段也用纯文本（避免未闭合代码块错乱），完成后用 Markdown 渲染。
    final useMarkdown = !isUser && !isStreaming;
    if (!useMarkdown) {
      return Text(
        content,
        style: TextStyle(
          fontSize: 15,
          color: isUser ? Colors.white : RuolanColors.of(context).onSurface,
          height: 1.5,
        ),
      );
    }
    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, color: RuolanColors.of(context).onSurface, height: 1.5),
        strong: TextStyle(fontSize: 15, color: RuolanColors.of(context).onSurface, fontWeight: FontWeight.bold, height: 1.5),
        em: TextStyle(fontSize: 15, color: RuolanColors.of(context).onSurface, fontStyle: FontStyle.italic, height: 1.5),
        listBullet: TextStyle(fontSize: 15, color: RuolanColors.of(context).onSurface, height: 1.5),
        h1: TextStyle(fontSize: 20, color: RuolanColors.of(context).onSurface, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: 18, color: RuolanColors.of(context).onSurface, fontWeight: FontWeight.bold),
        h3: TextStyle(fontSize: 16, color: RuolanColors.of(context).onSurface, fontWeight: FontWeight.bold),
        blockquote: TextStyle(fontSize: 15, color: RuolanColors.of(context).blockquote, height: 1.5),
        code: TextStyle(fontSize: 13, color: RuolanColors.of(context).onSurface, backgroundColor: RuolanColors.of(context).codeBg, fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: RuolanColors.of(context).codeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: RuolanColors.of(context).border),
        ),
        a: TextStyle(fontSize: 15, color: RuolanColors.of(context).primaryFg, decoration: TextDecoration.underline),
      ),
    );
  }

  Widget _buildAction(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? Colors.white.withValues(alpha: 0.18) : RuolanColors.of(context).chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser ? Colors.white.withValues(alpha: 0.4) : RuolanColors.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isUser ? Colors.white : RuolanColors.of(context).primaryFg),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: isUser ? Colors.white : RuolanColors.of(context).primaryFg)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? RuolanColors.of(context).avatarUser : RuolanColors.of(context).avatarAssistant,
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
