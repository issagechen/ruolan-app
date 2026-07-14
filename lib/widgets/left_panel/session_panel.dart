import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../providers/chat_provider.dart';

void showSessionPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFFFAF7F4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _SessionPanel(),
  );
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              const Text('会话',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5C3D2E))),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.add, color: Color(0xFF8B5E3C)),
                title: const Text('新会话'),
                onTap: () {
                  chat.newSession();
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE0D5CC)),
              ...chat.sessions.map((s) => _tile(context, chat, s)),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, ChatProvider chat, SessionMeta s) {
    final isCurrent = s.id == chat.currentSessionId;
    return ListTile(
      selected: isCurrent,
      selectedTileColor: const Color(0xFFF0E4DA),
      leading: Icon(
        isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
        color: const Color(0xFF8B5E3C),
      ),
      title: Text(s.title, style: const TextStyle(color: Color(0xFF5C3D2E))),
      onTap: () {
        chat.switchSession(s.id);
        Navigator.pop(context);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onPressed: () => _rename(context, chat, s),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context, chat, s),
          ),
        ],
      ),
    );
  }

  void _rename(BuildContext context, ChatProvider chat, SessionMeta s) {
    final ctrl = TextEditingController(text: s.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '会话名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) chat.renameSession(s.id, t);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChatProvider chat, SessionMeta s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除「${s.title}」？该会话的历史记录将一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              chat.deleteSession(s.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
